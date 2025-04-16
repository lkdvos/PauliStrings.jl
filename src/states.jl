# functions that involve pure states

using PauliStrings.Circuits


"""
    trace_zpart(o::Operator)

Computes `<0|o|0>`.
"""
function trace_zpart(o::Operator)
    s = 0
    for i in 1:length(o)
        if xcount(o.v[i], o.w[i]) == 0 && ycount(o.v[i], o.w[i]) == 0
            s += o.coef[i]
        end
    end
    return s * 2^o.N
end


function get_ox(state)
    N = length(state)
        ox = eye(N)
    for i in 1:N
        if state[i] == '1'
            x = XGate(N, i)
            ox = ox*x
        end
    end
    return compress(ox)
end

"""
    expect(o::Operator, state::String)

Computes the expectation value `<state|o|state>`.
State is a single binary string that represents a pure state in the computational basis.
"""
expect(o::Operator, state::String) = expect(o, state, state)


"""
    expect(o::Operator, in_state::String, out_state::String)

Computes the expectation value `<out_state|o|in_state>`.
`in_state` and `out_state` are single binary strings that represents pure states in the computational basis.
"""
function expect(o::Operator, in_state::String, out_state::String)
    @assert Set(in_state) ⊆ Set("01") "State must be a string of 0s and 1s"
    @assert Set(out_state) ⊆ Set("01") "State must be a string of 0s and 1s"
    @assert o.N == length(in_state) "State length does not match operator size"
    @assert o.N == length(out_state) "State length does not match operator size"
    ox_in = get_ox(in_state)
    ox_out = get_ox(out_state)
    o2 = ox_out*o*ox_in
    return trace_zpart(o2) / 2^o.N
end




"""
    expect_product(o1::Operator, o2::Operator, state::String)

Computes the expectation value `<state|o1*o2|state>`.
State is a single binary string that represents a pure state in the computational basis.
"""
function expect_product(o1::Operator, o2::Operator, state::String)
    @assert Set(state) ⊆ Set("01") "State must be a string of 0s and 1s"
    @assert o1.N == length(state) "State length does not match operator size"
    @assert o2.N == length(state) "State length does not match operator size"
    ox = get_ox(state)
    trace_product_z(ox*o1, o2*ox; scale=0) / 2^o1.N
end


"""
    expect(c::Circuit, state::String)

Computes the expectation value `<state|c|0>`.
State is a single binary string that represents a pure state in the computational basis.
"""
function expect(c::Circuit, state::String)
    @assert Set(state) ⊆ Set("01") "State must be a string of 0s and 1s"
    @assert c.N == length(state) "State length does not match circuit size"
    c2 = deepcopy(c)
    for i in 1:c.N
        if state[i] == '1'
            push!(c2, "X", i)
        end
    end
    U = compile(c2)
    return real(trace_zpart(U)) / 2^c.N
end

"""
    expect(c::Circuit, in_state::String, out_state::String)

Computes the expectation value of the state `out_state` after applying the circuit `c` to the state `in_state`.
"""
function expect(c::Circuit, in_state::String, out_state::String)
    @assert c.N == length(in_state) "State length does not match circuit size"
    @assert c.N == length(out_state) "State length does not match circuit size"
    c2 = deepcopy(c)
    for i in 1:c.N
        if in_state[i] == '1'
            pushfirst!(c2, "X", i)
        end
    end
    return expect(c2, out_state)
end
