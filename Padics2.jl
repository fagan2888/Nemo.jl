###########################################################################################
#
#   Padics2.jl : Padic numbers
#
###########################################################################################    

import Rings: O, valuation

export O, PadicNumberField, Padic, valuation, prime, precision, isexact

###########################################################################################
#
#   Data types and memory management
#
###########################################################################################

type padic_ctx
   p :: Int # can't make this a ZZ
   pinv :: Float64
   pow :: Ptr{Void}
   minpre :: Int
   maxpre :: Int
   mode :: Int
   function padic_ctx(p::ZZ)
      d = new(0, 0.0, C_NULL, 0, 0, 0)
      finalizer(d, _padic_ctx_clear_fn)
      ccall((:padic_ctx_init, :libflint), Void, (Ptr{padic_ctx}, Ptr{ZZ}, Int, Int, Cint), &d, &p, 0, 0, 1)
      return d
   end
end

function _padic_ctx_clear_fn(a :: padic_ctx)
   #ccall((:padic_ctx_clear, :libflint), Void, (Ptr{padic_ctx},), &a)
end

type Padic{S} <: Field
   u :: Int # can't make this a ZZ
   v :: Int
   N :: Int
   function Padic()
      d = new(0, 0, 0)
      ccall((:padic_init2, :libflint), Void, (Ptr{Padic}, Int), &d, 0)
      finalizer(d, _Padic_clear_fn)
      return d
   end
   function Padic(a::ZZ)
      z = Padic{S}()
      repr = bool(ccall((:padic_set_exact_fmpz, :libflint), Cint, (Ptr{Padic}, Ptr{ZZ}, Ptr{padic_ctx}), &z, &a, &eval(:($S))))
      !repr && error("Cannot represent negative integer exactly")
      z.N = -1
      return z
   end
   Padic(a::Int) = Padic{S}(ZZ(a))
end

function _Padic_clear_fn{S}(a :: Padic{S})
   ccall((:padic_clear, :libflint), Void, (Ptr{Padic{S}},), &a)
end

function O(n::ZZ)
   n <= 0 && throw(DomainError())
   n == 1 && error("O(p^0) cannot be constructed")
   if isprime(n)
      S = symbol("padic$(string(ZZ(n)))")
      d = Padic{S}()
      d.N = 1
      eval(:($S = $padic_ctx($n)))
      return d
   end
   for N = 2:nbits(n) + 1
      r = root(n, N)
      if r^N == n && isprime(r)
         S = symbol("padic$(string(ZZ(r)))")
         d = Padic{S}()
         d.N = N
         eval(:($S = $padic_ctx($r)))
         return d
      end
   end
   error("Unable to determine prime base in O(p^n)")
end

O(n::Int) = O(ZZ(n))

###########################################################################################
#
#   Basic manipulation
#
###########################################################################################

function prime{S}(::Type{Padic{S}})
   ctx = eval(:($S))
   z = ZZ()
   ccall((:padic_ctx_pow_ui, :libflint), Void, (Ptr{ZZ}, Int, Ptr{padic_ctx}), &z, 1, &ctx)
   return z 
end

precision{S}(a::Padic{S}) = a.N

valuation{S}(a::Padic{S}) = a.v

isexact{S}(a::Padic{S}) = a.N < 0

function zero{S}(::Type{Padic{S}})
   z = Padic{S}()
   ccall((:padic_zero, :libflint), Void, (Ptr{Padic},), &z)
   z.N = -1
   return z
end

function one{S}(::Type{Padic{S}})
   z = Padic{S}()
   z.N = 1
   ccall((:padic_one, :libflint), Void, (Ptr{Padic},), &z)
   z.N = -1
   return z
end

iszero{S}(a::Padic{S}) = bool(ccall((:padic_is_zero, :libflint), Cint, (Ptr{Padic},), &a)) && a.N == -1

isone{S}(a::Padic{S}) = bool(ccall((:padic_is_one, :libflint), Cint, (Ptr{Padic},), &a)) && a.N == -1

###########################################################################################
#
#   String I/O
#
###########################################################################################

function show{S}(io::IO, x::Padic{S})
   cstr = ccall((:padic_get_str, :libflint), Ptr{Uint8}, 
               (Ptr{Void}, Ptr{Padic}, Ptr{padic_ctx}), C_NULL, &x, &eval(:($S)))

   print(io, bytestring(cstr))

   ccall((:flint_free, :libflint), Void, (Ptr{Uint8},), cstr)
   if x.N >= 0
      print(io, " + O(")
      print(io, prime(Padic{S}))
      print(io, "^$(x.N))")
   end
end

function show{S}(io::IO, ::Type{Padic{S}})
   print(io, "p-adic number field")
end

###########################################################################################
#
#   Unary operators
#
###########################################################################################

function -{S}(x::Padic{S})
   if iszero(x)
      return x
   end
   x.N < 0 && error("Cannot compute infinite precision p-adic")
   z = Padic{S}()
   z.N = x.N
   ccall((:padic_neg, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &x, &eval(:($S)))
   return z
end

###########################################################################################
#
#   Binary operators
#
###########################################################################################

function +{S}(x::Padic{S}, y::Padic{S})
   z = Padic{S}()
   z.N = x.N < 0 ? y.N : (y.N < 0 ? x.N : min(x.N, y.N))
   if z.N < 0
      ccall((:padic_add_exact, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &x, &y, &eval(:($S)))
   else
      ccall((:padic_add, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &x, &y, &eval(:($S)))
   end
   return z
end

function -{S}(x::Padic{S}, y::Padic{S})
   z = Padic{S}()
   z.N = x.N < 0 ? y.N : (y.N < 0 ? x.N : min(x.N, y.N))
   if z.N < 0
      repr = bool(ccall((:padic_sub_exact, :libflint), Cint, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &x, &y, &eval(:($S))))
      !repr && error("Unable to represent exact result of subtraction")
   else
      ccall((:padic_sub, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &x, &y, &eval(:($S)))
   end
   return z
end

function *{S}(x::Padic{S}, y::Padic{S})
   z = Padic{S}()
   z.N = x.N < 0 ? (y.N < 0 ? -1 : y.N + x.v) : (y.N < 0 ? x.N + y.v : min(x.N + y.v, y.N + x.v))
   if z.N < 0
      ccall((:padic_mul_exact, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &x, &y, &eval(:($S)))
   else 
      ccall((:padic_mul, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &x, &y, &eval(:($S)))
   end
   return z
end

###########################################################################################
#
#   Ad hoc binary operators
#
###########################################################################################

function +{S}(x::Padic{S}, y::ZZ)
   if sign(y) < 0
      return x - (-y)
   end
   z = Padic{S}()
   z.N = x.N
   ccall((:padic_set_exact_fmpz, :libflint), Void, 
                (Ptr{Padic}, Ptr{ZZ}, Ptr{padic_ctx}), 
               &z, &y, &eval(:($S)))
   if z.N < 0
      ccall((:padic_add_exact, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &z, &x, &eval(:($S)))
   else
      ccall((:padic_add, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &z, &x, &eval(:($S)))
   end
   return z
end

+{S}(x::Padic{S}, y::Int) = x + ZZ(y)

+{S}(x::ZZ, y::Padic{S}) = y + x

+{S}(x::Int, y::Padic{S}) = y + ZZ(x)

function -{S}(x::Padic{S}, y::ZZ)
   if sign(y) < 0
      return x + (-y)
   end
   z = Padic{S}()
   z.N = x.N
   ccall((:padic_set_exact_fmpz, :libflint), Void, 
                (Ptr{Padic}, Ptr{ZZ}, Ptr{padic_ctx}), 
               &z, &y, &eval(:($S)))
   if z.N < 0
      repr = bool(ccall((:padic_sub_exact, :libflint), Cint, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &x, &z, &eval(:($S))))
      !repr && error("Unable to represent negative value exactly")
   else
      ccall((:padic_sub, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &x, &z, &eval(:($S)))
   end
   return z
end

function -{S}(x::ZZ, y::Padic{S})
   if sign(x) < 0
      return -y + (-x)
   end
   z = Padic{S}()
   z.N = y.N
   ccall((:padic_set_exact_fmpz, :libflint), Void, 
                (Ptr{Padic}, Ptr{ZZ}, Ptr{padic_ctx}), 
               &z, &x, &eval(:($S)))
   if z.N < 0
      repr = bool(ccall((:padic_sub_exact, :libflint), Cint, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &z, &y, &eval(:($S))))
      !repr && error("Unable to represent negative value exactly")
   else
      ccall((:padic_sub, :libflint), Cint, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &z, &y, &eval(:($S)))
   end
   return z
end

-{S}(x::Padic{S}, y::Int) = x - ZZ(y)

-{S}(x::Int, y::Padic{S}) = ZZ(x) - y

function *{S}(x::Padic{S}, y::ZZ)
   if sign(y) < 0
      return -(x*(-y))
   end
   if y == 0
      return zero(Padic{S})
   end
   z = Padic{S}()
   ccall((:padic_set_exact_fmpz, :libflint), Void, 
                (Ptr{Padic}, Ptr{ZZ}, Ptr{padic_ctx}), 
               &z, &y, &eval(:($S)))
   if x.N < 0
      z.N = -1
      ccall((:padic_mul_exact, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &z, &x, &eval(:($S)))
   else
      z.N = x.N + z.v
      ccall((:padic_mul, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &z, &x, &eval(:($S)))
   end
   return z
end

*{S}(x::ZZ, y::Padic{S}) = y*x

*{S}(x::Padic{S}, y::Int) = x*ZZ(y)

*{S}(x::Int, y::Padic{S}) = y*ZZ(x)

###########################################################################################
#
#   Comparison
#
###########################################################################################

function =={S}(a::Padic{S}, b::Padic{S})
   N = a.N < 0 ? b.N : (b.N < 0 ? a.N : min(a.N, b.N))
   if N < 0
      return bool(ccall((:padic_equal, :libflint), Cint, 
                (Ptr{Padic}, Ptr{Padic}), &a, &b))
   else
      z = Padic{S}()
      z.N = N
      ccall((:padic_sub, :libflint), Void, 
                (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), 
               &z, &a, &b, &eval(:($S)))
      return bool(ccall((:padic_is_zero, :libflint), Cint, 
                (Ptr{Padic},), &z))
   end
end

###########################################################################################
#
#   Ad hoc comparison
#
###########################################################################################

function =={S}(a::Padic{S}, b::ZZ)
   if a.N == -1
      if sign(b) < 0
         return false
      end
      z = Padic{S}(b)
   else
      z = Padic{S}()
      z.N = a.N
      ccall((:padic_set_fmpz, :libflint), Void, 
                (Ptr{Padic}, Ptr{ZZ}, Ptr{padic_ctx}), 
               &z, &b, &eval(:($S)))
   end
   return bool(ccall((:padic_equal, :libflint), Cint, 
                (Ptr{Padic}, Ptr{Padic}), &a, &z))
end

=={S}(a::Padic{S}, b::Int) = a == ZZ(b)

=={S}(a::ZZ, b::Padic{S}) = b == a

=={S}(a::Int, b::Padic{S}) = b == ZZ(a)

###########################################################################################
#
#   Exact division
#
###########################################################################################

function divexact{S}(a::Padic{S}, b::Padic{S})
   b == 0 && throw(DivideError())
   z = Padic{S}()
   if a.N < 0
      if b.N < 0
         z.N = -1
         repr = bool(ccall((:padic_div_exact, :libflint), Cint, (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}), &z, &a, &b))
         !repr && error("Unable to compute quotient of p-adics to infinite precision")
         return z
      end
      z.N = b.N - 2*b.v + a.v
   elseif b.N < 0
      z.N = a.N - b.v
   else
      z.N = min(a.N - b.v, b.N - 2*b.v + a.v)
   end
   ccall((:padic_div, :libflint), Cint, (Ptr{Padic}, Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), &z, &a, &b, &eval(:($S)))
   return z
end

###########################################################################################
#
#   Inversion
#
###########################################################################################

function inv{S}(a::Padic{S})
   z = Padic{S}()
   if a.N < 0
      z.N = -1
      repr = bool(ccall((:padic_inv_exact, :libflint), Cint, (Ptr{Padic}, Ptr{Padic}), &z, &a))      
      !repr && error("Unable to invert infinite precision p-adic")
   else
      z.N = a.N - 2*a.v
      ccall((:padic_inv, :libflint), Cint, (Ptr{Padic}, Ptr{Padic}, Ptr{padic_ctx}), &z, &a, &eval(:($S)))
   end
   return z
end

###########################################################################################
#
#   PadicNumberField constructor
#
###########################################################################################

function PadicNumberField(p::ZZ)
   !isprime(p) && error("Prime base required in PadiCNumberField")
   S = symbol("padic$(string(ZZ(p)))")
   R = Padic{S}
   eval(:($S = $padic_ctx($p)))
   return R
end

PadicNumberField(p::Int) = PadicNumberField(ZZ(p))
