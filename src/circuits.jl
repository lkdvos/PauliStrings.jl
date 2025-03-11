

module Circuits
export CCXGate, TGate, TdgGate, HGate, SwapGate, PhaseGate, SXGate
export Sgate, SXGate
export CXGate, CYGate, CZGate, CNOTGate, CPhaseGate
export MCZGate
export CSXGate, CSXdgGate
export Circuit, compile, expect
export grover_diffusion
export XGate, YGate, ZGate
export XXPlusYYGate
using PauliStrings

single_gates = ["X", "Y", "Z", "H", "S", "T", "Tdg", "Phase"]
two_gates = ["CNOT", "Swap", "CX", "CY", "CZ", "CCX", "CSX", "CSXdg", "XXPlusYY", "CPhase"]
other = ["CCX", "Noise", "MCZ"]

allowed_gates = vcat(single_gates, two_gates, other)



mutable struct Circuit
    N::Int
    gates::Vector{Tuple{String,Vector{Int},Vector{Real}}}
    max_strings::Int
    noise_amplitude::Real
end


"""
    Circuit(N::Int; max_strings=2^30, noise_amplitude=0)

Creates an empty quantum circuit with `N` qubits. `max_strings` is the maximum number of strings to keep in the operator. `noise_amplitude` is the amplitude of the noise gate.
"""
Circuit(N::Int; max_strings=2^30, noise_amplitude=0) = Circuit(N, [], max_strings, noise_amplitude)


function get_site_pars(gate::String, site_pars)
    site_pars = collect(site_pars)
    if gate in single_gates
        sites = [Int(site_pars[1])]
        pars = site_pars[2:end]
    elseif gate in two_gates
        sites = [Int(site_pars[1]), Int(site_pars[2])]
        pars = site_pars[3:end]
    else
        gate in other
        sites = Int.(site_pars)
        pars = []
    end
    return sites, pars
end


"""
    push!(c::Circuit, gate::String, sites::Real...)

Adds a gate to the circuit `c`. The gate is specified by a string `gate` and a list of sites `sites`.
The gates have the same naming convention as in Qiskit.
Allowed gates are: "X", "Y", "Z", "H", "S", "T", "Tdg", "Phase", "CNOT", "Swap", "CX", "CY", "CZ", "CCX", "CSX", "CSXdg", "MCZ", "Noise".
"""
function Base.push!(c::Circuit, gate::String, site_pars::Real...)
    @assert gate in allowed_gates "Unknown gate: $(gate)"
    sites, pars = get_site_pars(gate, site_pars)
    push!(c.gates, (gate, sites, pars))
end

"""
    pushfirst!(c::Circuit, gate::String, sites::Real...)

Adds a gate to the beginning of the circuit `c`.
"""
function Base.pushfirst!(c::Circuit, gate::String, site_pars::Real...)
    @assert gate in allowed_gates "Unknown gate: $(gate)"
    sites, pars = get_site_pars(gate, site_pars)
    pushfirst!(c.gates, (gate, sites, pars))
end



function XYZGate(N::Int, i::Int, type::String)
    O = Operator(N)
    O += type, i
    return O
end



"""
    XGate(N::Int, i::Int)
    YGate(N::Int, i::Int)
    ZGate(N::Int, i::Int)
    HGate(N::Int, i::Int)
    SGate(N::Int, i::Int)
    TGate(N::Int, i::Int)
    TdgGate(N::Int, i::Int)
    SXGate(N::Int, i::Int)

Creates a single qubit gate acting on qubit `i` of a `N` qubit system.
"""
XGate(N::Int, i::Int) = XYZGate(N, i, "X")
YGate(N::Int, i::Int) = XYZGate(N, i, "Y")
ZGate(N::Int, i::Int) = XYZGate(N, i, "Z")
HGate(N::Int, i::Int) = (XGate(N, i) + ZGate(N, i)) / sqrt(2)
SGate(N::Int, i::Int) = PhaseGate(N, i, pi / 2)
TGate(N::Int, i::Int) = PhaseGate(N, i, pi / 4)
TdgGate(N::Int, i::Int) = dagger(TGate(N::Int, i::Int))
SXGate(N::Int, i::Int) = ((1 - 1im) * XGate(N, i) + (1 + 1im) * eye(N)) / 2

"""
    PhaseGate(N::Int, i::Int, theta::Real)

Creates a phase gate acting on qubit `i` of a `N` qubit system with phase `theta`.
"""
PhaseGate(N::Int, i::Int, theta::Real) = (eye(N) + ZGate(N, i)) / 2 + (eye(N) - ZGate(N, i)) / 2 * exp(1im * theta)


"""
    CPhaseGate(N::Int, i::Int, j::Int, theta::Real)

Controled phase gate with control qubit `i` and target qubit `j` of a `N` qubit system.
"""
function CPhaseGate(N::Int, i::Int, j::Int, theta::Real)
    O = Operator(N)
    c = (exp(1im * theta) - 1) / 4
    O += c, "Z", i, "Z", j
    O -= c, "Z", i
    O -= c, "Z", j
    O += (exp(1im * theta) + 3) / 4
    return O
end


function CXYZGate(N::Int, i::Int, j::Int, type::String)
    O = Operator(N)
    O -= "Z", i, type, j
    O += type, j
    O += "Z", i
    O += eye(N)
    return O / 2
end


"""
    CXGate(N::Int, i::Int, j::Int)
    CYGate(N::Int, i::Int, j::Int)
    CZGate(N::Int, i::Int, j::Int)
    CNOTGate(N::Int, i::Int, j::Int)

Creates a two qubit gate with control qubit `i` and target qubit `j` of a `N` qubit system.
"""
CXGate(N::Int, i::Int, j::Int) = CXYZGate(N, i, j, "X")
CYGate(N::Int, i::Int, j::Int) = CXYZGate(N, i, j, "Y")
CZGate(N::Int, i::Int, j::Int) = CXYZGate(N, i, j, "Z")
CNOTGate(N::Int, i::Int, j::Int) = CXGate(N, i, j)


"""
    SwapGate(N::Int, i::Int, j::Int)

Creates a swap gate between qubits `i` and `j` of a `N` qubit system.
"""
function SwapGate(N::Int, i::Int, j::Int)
    O = Operator(N)
    O += "X", i, "X", j
    O += "Y", i, "Y", j
    O += "Z", i, "Z", j
    O += eye(N)
    return O / 2
end


"""
    XXPlusYYGate(N::Int, i::Int, j::Int, theta::Real, beta::Real)

XX+YY gate between qubits `i` and `j` of a `N` qubit system.
"""
function XXPlusYYGate(N::Int, i::Int, j::Int, theta::Real, beta::Real)
    O = Operator(N)
    O += 0.5, "Z", i, "Z", j
    O += 0.5
    O += cos(theta / 2) / 2
    O -= cos(theta / 2) / 2, "Z", i, "Z", j
    c = -1im * sin(theta / 2) * exp(1im * beta) / 4
    O += c, "X", i, "X", j
    O -= 1im * c, "Z", i, "Y", j
    O += 1im * c, "Y", i, "Z", j
    O += c, "Y", i, "Y", j
    c = -1im * sin(theta / 2) * exp(-1im * beta) / 4
    O += c, "X", i, "X", j
    O += 1im * c, "Z", i, "Y", j
    O -= 1im * c, "Y", i, "Z", j
    O += c, "Y", i, "Y", j
    return O
end

"""
    CSXGate(N::Int, i::Int, j::Int)
    CSXdgGate(N::Int, i::Int, j::Int)

Controlled sqrt X gate and its dagger
"""
function CSXGate(N::Int, i::Int, j::Int)
    O = Operator(N)
    O += -1 + 1im, "Z", i, "X", j
    O += 1 - 1im, "Z", i
    O += 1 - 1im, "X", j
    O += eye(N) * (3 + 1im)
    return O / 4
end
CSXdgGate(N::Int, i::Int, j::Int) = dagger(CSXGate(N, i, j))

"""
    CCXGate(N::Int, i::Int, j::Int, k::Int)

Tofolli gate with control qubits `i` and `j` and target qubit `k` of a `N` qubit system.
"""
function CCXGate(N::Int, i::Int, j::Int, k::Int)
    O = Operator(N)
    O += "Z", i, "Z", j, "X", k
    O -= "Z", i, "X", k
    O -= "Z", j, "X", k
    O += "X", k
    O -= "Z", i, "Z", j
    O += "Z", i
    O += "Z", j
    O += eye(N) * 3
    return O / 4
end

"""
    MCZGate(N::Int, sites::Int...)

Creates a multi-controlled Z gate acting on `sites` qubits of a `N` qubit system.
"""
function MCZGate(N::Int, sites::Int...)
    sites = collect(sites)
    U = eye(N) - 2 * all_z(N, sites) / 2^N
    for i in sites
        U = XGate(N, i) * U * XGate(N, i)
    end
    return compress(U)
end

MCZGate(N::Int) = MCZGate(N, 1:N...)

"""
    grover_diffusion(N::Int, sites::Int...)

Creates the Grover diffusion operator acting on `sites` qubits of a `N` qubit system.
"""
function grover_diffusion(N::Int, sites::Int...)
    U = MCZGate(N, sites...)
    for i in sites
        U = HGate(N, i) * U * HGate(N, i)
    end
    return compress(U)
end



"""
    compile(c::Circuit)

Compiles the quantum circuit `c` into a unitary operator. Applies the gates in the order they were added.
Applies noise gates if present and trim the operator to `c.max_strings` strings at each step.
"""
function compile(c::Circuit)
    U = eye(c.N)
    for (gate, sites, args) in c.gates
        if gate == "Noise"
            U = add_noise(U, c.noise_amplitude)
        elseif gate in allowed_gates
            O = eval(Symbol(gate * "Gate"))(c.N, sites..., args...)
            U = O * U
        else
            error("Unknown gate: $gate")
        end
        U = compress(U)
        U = trim(U, c.max_strings)
    end
    return U
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


end
