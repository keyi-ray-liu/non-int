const GB = 2^30

# SD class in Julia
struct SD
    L::Int
    N::Int
    arr::Int
    left_bias::Float64
    arr_bias::Float64
    right_bias::Float64
    source_coupling::Float64
    drain_coupling::Float64
    single::Bool
    t::Float64
    contact_source::Int
    contact_drain::Int
    arr_source::Vector{Int}
    source_scaling::Vector{Float64}
    arr_drain::Vector{Int}
    drain_scaling::Vector{Float64}

    function SD(L::Int, N::Int, arr::Int, left_bias::Float64, arr_bias::Float64, right_bias::Float64, source_coupling::Float64, drain_coupling::Float64; single::Bool=false, t::Float64=-1.0)
        contact_source = L 
        contact_drain = L + arr^2 + 1
        arr_source, source_scaling, arr_drain, drain_scaling = setup_connections(L, arr, single, contact_source, contact_drain)
        new(L, N, arr, left_bias, arr_bias, right_bias, source_coupling, drain_coupling, single, t, contact_source, contact_drain, arr_source, source_scaling, arr_drain, drain_scaling)
    end

    # Function to set up source and drain connections based on single flag and array size
    function setup_connections(L::Int, arr::Int, single::Bool, contact_source::Int, contact_drain::Int)
        if single
            arr_source = [contact_source + 1 + arr * ((arr - 1) ÷ 2)]
            source_scaling = [1.0]
            arr_drain = [contact_drain - 1 - arr * ((arr - 1) ÷ 2)]
            drain_scaling = [1.0]
        else
            arr_source = [contact_source + i for i in 1:arr:arr^2]
            source_scaling = ones(Float64, arr)
            arr_drain = [contact_source + j for j in arr:arr:arr^2]
            drain_scaling = ones(Float64, arr)
            if arr == 3
                source_scaling[2] = 2
                drain_scaling[2] = 2
            end
        end
        return arr_source, source_scaling, arr_drain, drain_scaling
    end
end

# Function to set up the Hamiltonian matrix
function set_hij(sd::SD, path::String, mod::String; savehij::Bool=false)
    t = sd.t
    L = sd.L
    arr = sd.arr
    arr_size = arr^2
    left = sd.left_bias
    cent = sd.arr_bias
    right = sd.right_bias
    source_coupling = sd.source_coupling
    drain_coupling = sd.drain_coupling
    contact_source = sd.contact_source
    contact_drain = sd.contact_drain
    arr_source = sd.arr_source
    arr_drain = sd.arr_drain
    source_scaling = sd.source_scaling
    drain_scaling = sd.drain_scaling

    total = 2 * L + arr_size
    M = zeros(Float64, total, total)

    # Left section
    for i in 1:(L - 1)
        M[i + 1, i] = M[i, i + 1] = t
        M[i, i] = left
    end
    M[L, L] = left

    # Coupling between sections
    for i in 1:length(arr_source)
        site = arr_source[i]
        M[contact_source, site] = M[site, contact_source] = source_coupling * t * source_scaling[i]
    end
    for i in 1:length(arr_drain)
        site = arr_drain[i]
        M[contact_drain, site] = M[site, contact_drain] = drain_coupling * t * drain_scaling[i]
    end

    # Right section
    for i in (L + arr_size + 1):(total - 1)
        M[i + 1, i] = M[i, i + 1] = t
        M[i, i] = right
    end
    M[total, total] = right

    # Central array section
    for i in 1:arr
        for j in 1:arr
            idx = (i - 1) * arr + j + L
            M[idx, idx] += cent
            if i < arr
                M[idx, idx + arr] = t
                M[idx + arr, idx] = t
            end
            if j < arr
                M[idx, idx + 1] = t
                M[idx + 1, idx] = t
            end
        end
    end

    if M != transpose(conj(M))
        throw(DomainError("Matrix M is not Hermitian!"))
    end

    if savehij
        open(path * "/M" * mod * ".txt", "w") do f
            for row in eachrow(M)
                println(f, join(row, " "))
            end
        end
    end

    return M
end

# Function to initialize states
function set_init(sd::SD)
    init = zeros(ComplexF64, sd.L * 2 + sd.arr^2)
    init[1:sd.N] .= 1.0 # Set the first N elements
    return init
end



# Helper function to save results
function save_result(::SD, currents::Array{Float64, 2}, occs::Array{Float64, 2}, CCs::Array{ComplexF64, 3}, timestep::Float64, fin::Float64, path::String)
    mkpath(path)

    open(path * "/times", "w") do f
        writedlm(f, 0:timestep:fin)
    end
    open(path * "/currentSD", "w") do f
        writedlm(f, currents)
    end
    open(path * "/occ", "w") do f
        writedlm(f, occs)
    end
end