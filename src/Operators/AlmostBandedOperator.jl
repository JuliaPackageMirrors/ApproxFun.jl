

export MutableAlmostBandedOperator, adaptiveqr!



function indexrange(b::BandedBelowOperator,k::Integer)
    ret = bandrange(b) + k
  
    (ret[1] < 1) ? (1:ret[end]) : ret
end

index(b::BandedBelowOperator)=1-bandrange(b)[1]



## MutableAlmostBandedOperator


type MutableAlmostBandedOperator{T<:Number,M<:BandedOperator,R<:RowOperator} <: BandedBelowOperator
    bc::Vector{R}
    op::M
    data::ShiftArray{T}   #Shifted to encapsolate bandedness
    filldata::Array{T,2}
    
    bcdata::Array{T,2}
    bcfilldata::Array{T,2}
    
    datalength::Int
    
    bandrange::Range1{Int}
end

domainspace(M::MutableAlmostBandedOperator)=domainspace(M.op)
rangespace(M::MutableAlmostBandedOperator)=rangespace(M.op)



#TODO: index(op) + 1 -> length(bc) + index(op)
function MutableAlmostBandedOperator{R<:RowOperator}(bc::Vector{R},op::BandedOperator)
    data = ShiftArray(index(op))
    
    nbc = length(bc)
    bcdata = Float64[bc[k][j] for k=1:nbc, j=1:length(bandrange(op))+nbc-1]
    bcfilldata = eye(nbc)
                
    br=(bandrange(op)[1]-nbc):(length(bandrange(op))-1)
    MutableAlmostBandedOperator(bc,op,data,Array(Float64,0,nbc),bcdata,bcfilldata,0, br )
end

function MutableAlmostBandedOperator{T<:Operator}(B::Vector{T})
    bcs = RowOperator[B[k] for k=1:length(B)-1]
    
    @assert typeof(B[end]) <: BandedOperator
    
    MutableAlmostBandedOperator(bcs,B[end])
end


index(B::MutableAlmostBandedOperator)=index(B.op)
numbcs(B::MutableAlmostBandedOperator)=length(B.bc)

# for bandrange, we save room for changed entries during Givens
bandrange(B::MutableAlmostBandedOperator)=B.bandrange
datalength(B::MutableAlmostBandedOperator)=B.datalength




function Base.getindex(B::MutableAlmostBandedOperator,kr::Range1,jr::Range1)
    ret = spzeros(length(kr),length(jr))
    
    
    for k = kr
        if k <= datalength(B) || k <= numbcs(B)
            for j=jr
                ret[k,j] = B[k,j]
            end
        else
            ir = (bandrange(B) + k)::Range1{Int64}
            
            for j=max(ir[1],jr[1]):min(ir[end],jr[end])
                ret[k-kr[1]+1,j-jr[1]+1] = B[k,j]
            end
        end
    end
    
    ret
end

function fillgetindex(B::MutableAlmostBandedOperator,k::Integer,j::Integer)
    nbc = numbcs(B)
    ret = 0.
    
    if k <= nbc
        for m=1:nbc
            bcv = B.bc[m][j]::Float64        
            ret += B.bcfilldata[k,m]*bcv
        end
    else
        for m=1:nbc
            bcv = B.bc[m][j]::Float64
            ret += B.filldata[k-nbc,m]*bcv
        end    
    end
    
    ret
end

function datagetindex(B::MutableAlmostBandedOperator,k::Integer,j::Integer)  
    nbc = numbcs(B)::Integer
    if k <= nbc
        B.bcdata[k,j] 
    else
        B.data[k-nbc,j-k+nbc]
    end
end

function Base.getindex(B::MutableAlmostBandedOperator,k::Integer,j::Integer)  
    ir = indexrange(B,k)::Range1{Int64}
    nbc = numbcs(B)::Integer
    
    if k <= nbc
        if j <= ir[end]
            B.bcdata[k,j] 
        else
            fillgetindex(B,k,j)
        end
    elseif k-nbc <= datalength(B) && j <= ir[end] && ir[1] <= j
        B.data[k-nbc,j-k+nbc]
    elseif k-nbc <= datalength(B) && j > ir[end]
        fillgetindex(B,k,j)
    else
        B.op[k-nbc,j]##TODO: Slow
    end
end


getindex!(b::MutableAlmostBandedOperator,kr::Range1,jr::Range1)=resizedata!(b,kr[end])[kr,jr]
getindex!(b::MutableAlmostBandedOperator,kr::Integer,jr::Integer)=resizedata!(b,kr)[kr,jr]

function resizedata!{T<:Number,M<:BandedOperator}(B::MutableAlmostBandedOperator{T,M},n::Integer)
    l = datalength(B)
    nbc=numbcs(B)
    if n > l
        resize!(B.data,2n,length(B.bandrange))
        
        newfilldata=zeros(2n,nbc)
        newfilldata[1:l,:]=B.filldata[1:l,:]
        B.filldata=newfilldata
        
        addentries!(B.op,B.data,l+1:n)
        
        B.datalength = n
    end
    
    B
end

function Base.setindex!(B::MutableAlmostBandedOperator,x,k::Integer,j::Integer)
    nbc = numbcs(B)

    if k<=nbc
        B.bcdata[k,j] = x
    else
        resizedata!(B,k)      
        B.data[k-nbc,j-k+nbc] = x
    end
    x
end

function setfilldata!(B::MutableAlmostBandedOperator,x,k::Integer,j::Integer)
    if k<= numbcs(B)
        B.bcfilldata[k,j] = x
    else
        B.filldata[k-numbcs(B),j] = x
    end
end

getfilldata(B::MutableAlmostBandedOperator,k::Integer,j::Integer)=(k<=numbcs(B))?B.bcfilldata[k,j]:B.filldata[k-numbcs(B),j]



##TODO: decide adaptive resize
function givensreduce!(B::MutableAlmostBandedOperator,v::Vector,k1::Integer,k2::Integer,j1::Integer)
    a=datagetindex(B,k1,j1)::Float64
    b=datagetindex(B,k2,j1)::Float64
    sq=sqrt(a*a + b*b)
    a=a/sq;b=b/sq
    
    v[k1],v[k2] = a*v[k1] + b*v[k2],-b*v[k1] + a*v[k2]    
    
    
    #TODO: Assuming that left rows are already zero
    
    ir1=indexrange(B,k1)::Range1{Int64}
    ir2=indexrange(B,k2)::Range1{Int64}    
    
    for j = j1:ir1[end]
        B1 = datagetindex(B,k1,j)::Float64
        B2 = datagetindex(B,k2,j)::Float64
        
        B[k1,j],B[k2,j]= a*B1 + b*B2,-b*B1 + a*B2
    end
    
    for j=ir1[end]+1:ir2[end]
        B1 = fillgetindex(B,k1,j)::Float64
        B2 = datagetindex(B,k2,j)::Float64
        
        B[k2,j]=a*B2 - b*B1
    end
    
    for j=1:numbcs(B)
        B1 = getfilldata(B,k1,j)::Float64
        B2 = getfilldata(B,k2,j)::Float64
    
        setfilldata!(B, a*B1 + b*B2,k1,j)
        setfilldata!(B,-b*B1 + a*B2,k2,j)    
    end
    

    B
end

function givensreduce!(B::MutableAlmostBandedOperator,v::Vector,k1::Range1,j1::Integer)
  for k=k1[2]:k1[end]
    givensreduce!(B,v,k1[1],k,j1)
  end
end

givensreduce!(B::MutableAlmostBandedOperator,v::Vector,j::Integer)=givensreduce!(B,v,j:(j-bandrange(B)[1]),j)


function backsubstitution!(B::MutableAlmostBandedOperator,u)
    n=length(u)
    b=bandrange(B)[end]::Integer
    nbc = numbcs(B)
    
    
    for k=n:-1:n-b
        for j=k+1:n
            u[k]-=B[k,j]*u[j]
        end
          
        u[k] /= B[k,k]
    end
    
    pk = zeros(nbc)
    for k=n-b-1:-1:1
        for j=1:nbc
            pk[j] += u[k+b+1]*B.bc[j][k+b+1]
        end
        
        for j=k+1:k+b
            u[k]-=B[k,j]*u[j]
        end
        
        for j=1:nbc
            u[k] -= getfilldata(B,k,j)*pk[j]
        end
          
        u[k] /= B[k,k]
    end
  
  u
end


adaptiveqr(M::Vector{Operator},b::Vector{Any})=IFun(adaptiveqr(M,vcat(map(f-> typeof(f)<: IFun? coefficients(f,1) :  f,b)...)),b[end].domain)
adaptiveqr{T<:Operator}(B::Vector{T},v::Vector) = adaptiveqr!(MutableAlmostBandedOperator(B),copy(v))
function adaptiveqr!(B::MutableAlmostBandedOperator,v::Vector)
    u=[v,zeros(100)]
    
    l = length(v) + 100  
    resizedata!(B,l)
    
    
    j=1
    b=-bandrange(B)[1]
    
    tol=.001eps()
    
    
    ##TODO: check js
    while norm(u[j:j+b-1]) > tol
        if j + b == l
            u = [u,zeros(l)]      
            l *= 2
            resizedata!(B,l)
        end
        
        
        givensreduce!(B,u,j)
        j+=1
    end
  
    backsubstitution!(B,u[1:j-1])
end

