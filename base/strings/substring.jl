# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
    SubString(s::AbstractString, i::Integer, j::Integer=endof(s))
    SubString(s::AbstractString, r::UnitRange{<:Integer})

Like [`getindex`](@ref), but returns a view into the parent string `s`
within range `i:j` or `r` respectively instead of making a copy.

# Examples
```jldoctest
julia> SubString("abc", 1, 2)
"ab"

julia> SubString("abc", 1:2)
"ab"

julia> SubString("abc", 2)
"bc"
```
"""
struct SubString{T<:AbstractString} <: AbstractString
    string::T
    offset::Int
    ncodeunits::Int

    function SubString{T}(s::T, i::Int, j::Int) where T<:AbstractString
        i ≤ j || return new(s, i-1, 0)
        @boundscheck begin
            checkbounds(s, i:j)
            @inbounds isvalid(s, i) || string_index_err(s, i)
            @inbounds isvalid(s, j) || string_index_err(s, j)
        end
        return new(s, i-1, nextind(s,j)-i)
    end
end

SubString(s::T, i::Int, j::Int) where {T<:AbstractString} = SubString{T}(s, i, j)
SubString(s::AbstractString, i::Integer, j::Integer=endof(s)) = SubString(s, Int(i), Int(j))
SubString(s::AbstractString, r::UnitRange{<:Integer}) = SubString(s, first(r), last(r))

function SubString(s::SubString, i::Int, j::Int)
    @boundscheck i ≤ j && checkbounds(s, i:j)
    SubString(s.string, s.offset+i, s.offset+j)
end

SubString(s::AbstractString) = SubString(s, 1, endof(s))
SubString{T}(s::T) where {T<:AbstractString} = SubString{T}(s, 1, endof(s))

convert(::Type{SubString{S}}, s::AbstractString) where {S<:AbstractString} =
    SubString(convert(S, s))

String(s::SubString{String}) = unsafe_string(pointer(s.string, s.offset+1), s.ncodeunits)

ncodeunits(s::SubString) = s.ncodeunits
codeunit(s::SubString) = codeunit(s.string)
length(s::SubString) = length(s.string, s.offset+1, s.offset+s.ncodeunits)

function codeunit(s::SubString, i::Integer)
    @boundscheck checkbounds(s, i)
    @inbounds return codeunit(s.string, s.offset + i)
end

function next(s::SubString, i::Integer)
    @boundscheck checkbounds(s, i)
    @inbounds c, i = next(s.string, s.offset + i)
    return c, i - s.offset
end

function getindex(s::SubString, i::Integer)
    @boundscheck checkbounds(s, i)
    @inbounds return getindex(s.string, s.offset + i)
end

function isvalid(s::SubString, i::Integer)
    ib = true
    @boundscheck ib = checkbounds(Bool, s, i)
    @inbounds return ib && isvalid(s.string, s.offset + i)
end

function thisind(s::SubString, i::Int)
    @boundscheck 0 ≤ i ≤ ncodeunits(s)+1 || throw(BoundsError(s, i))
    @inbounds return thisind(s.string, s.offset + i) - s.offset
end
function nextind(s::SubString, i::Int, n::Int)
    @boundscheck 0 ≤ i < ncodeunits(s)+1 || throw(BoundsError(s, i))
    @inbounds return nextind(s.string, s.offset + i, n) - s.offset
end
function nextind(s::SubString, i::Int)
    @boundscheck 0 ≤ i < ncodeunits(s)+1 || throw(BoundsError(s, i))
    @inbounds return nextind(s.string, s.offset + i) - s.offset
end
function prevind(s::SubString, i::Int, n::Int)
    @boundscheck 0 < i ≤ ncodeunits(s)+1 || throw(BoundsError(s, i))
    @inbounds return prevind(s.string, s.offset + i, n) - s.offset
end
function prevind(s::SubString, i::Int)
    @boundscheck 0 < i ≤ ncodeunits(s)+1 || throw(BoundsError(s, i))
    @inbounds return prevind(s.string, s.offset + i) - s.offset
end

function cmp(a::SubString{String}, b::SubString{String})
    na = sizeof(a)
    nb = sizeof(b)
    c = ccall(:memcmp, Int32, (Ptr{UInt8}, Ptr{UInt8}, UInt),
              pointer(a), pointer(b), min(na, nb))
    return c < 0 ? -1 : c > 0 ? +1 : cmp(na, nb)
end

# don't make unnecessary copies when passing substrings to C functions
cconvert(::Type{Ptr{UInt8}}, s::SubString{String}) = s
cconvert(::Type{Ptr{Int8}}, s::SubString{String}) = s

function unsafe_convert(::Type{Ptr{R}}, s::SubString{String}) where R<:Union{Int8, UInt8}
    convert(Ptr{R}, pointer(s.string)) + s.offset
end

pointer(x::SubString{String}) = pointer(x.string) + x.offset
pointer(x::SubString{String}, i::Integer) = pointer(x.string) + x.offset + (i-1)

"""
    reverse(s::AbstractString) -> AbstractString

Reverses a string. Technically, this function reverses the codepoints in a string and its
main utility is for reversed-order string processing, especially for reversed
regular-expression searches. See also [`reverseind`](@ref) to convert indices in `s` to
indices in `reverse(s)` and vice-versa, and [`Unicode.graphemes`](@ref Base.Unicode.graphemes) to
operate on user-visible "characters" (graphemes) rather than codepoints.
See also [`Iterators.reverse`](@ref) for
reverse-order iteration without making a copy. Custom string types must implement the
`reverse` function themselves and should typically return a string with the same type
and encoding. If they return a string with a different encoding, they must also override
`reverseind` for that string type to satisfy `s[reverseind(s,i)] == reverse(s)[i]`.

# Examples
```jldoctest
julia> reverse("JuliaLang")
"gnaLailuJ"

julia> reverse("ax̂e") # combining characters can lead to surprising results
"êxa"

julia> using Unicode

julia> join(reverse(collect(graphemes("ax̂e")))) # reverses graphemes
"ex̂a"
```
"""
function reverse(s::Union{String,SubString{String}})::String
    sprint() do io
        i, j = start(s), endof(s)
        while i ≤ j
            c, j = s[j], prevind(s, j)
            write(io, c)
        end
    end
end

getindex(s::AbstractString, r::UnitRange{<:Integer}) = SubString(s, r)
