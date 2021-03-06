## Linear Solve

function linsolve(A::Operator,b;kwds...)
    if dimension(domain(A)) > 1
        pdesolve(A,b;kwds...)
    elseif isambiguous(domainspace(A))
        A=choosespaces(A,b)
        if isambiguous(domainspace(A))
            error("Cannot infer spaces")
        end
        linsolve(A,b;kwds...)
    else
        linsolve(qrfact(A),b;kwds...)
    end
end


function linsolve{OO<:Operator}(A::Array{OO},b;kwds...)
    if dimension(domain(A[end])) > 1
        pdesolve(A,b;kwds...)
    else
        linsolve(interlace(A),b;kwds...)
    end
end

for p in (1,2)
    @eval begin
        \{T<:Operator}(A::Array{T,$p},b::Union{Array,Number,Fun}) = linsolve(A,b)
        \{T<:Operator,F<:Fun}(A::Array{T,$p},b::Vector{F}) = linsolve(A,b)
        \{T<:Operator,F<:Number}(A::Array{T,$p},b::Vector{F}) = linsolve(A,b)
    end
end
\(A::Operator,b) = linsolve(A,b)
