%lang starknet

%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.syscalls import get_tx_signature

# Stores a map for ID of the Poll -> Public Key of the owner who created the poll
@storage_var
func poll_owner_public_key(poll_id : felt) -> (public_key : felt):
end

# A storage_var can accept a Tuple (poll_id, voter_public_key) and return a single felt.
# This can also be done in vice-versa manner
@storage_var
func registered_voters(poll_id : felt, voter_public_key : felt) -> (is_registered : felt):
end

@storage_var
func voting_state(poll_id : felt, answer : felt) -> (n_votes : felt):
end

@storage_var
func voter_state(poll_id : felt, voter_public_key : felt) -> (has_voted : felt):
end

@storage_var
func result_recorder() -> (address : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        result_recorder_address : felt):
    result_recorder.write(value=result_recorder_address)
    return ()
end

@external
func init_poll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        poll_id : felt, public_key : felt) -> (result : felt):
    let (is_poll_id_taken) = poll_owner_public_key.read(poll_id=poll_id)

    # Verify that the poll ID is available.
    assert is_poll_id_taken = 0

    poll_owner_public_key.write(poll_id=poll_id, value=public_key)
    return (result=1)
end

@external
func register_voter{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,
        ecdsa_ptr : SignatureBuiltin*}(poll_id : felt, voter_public_key : felt):
    let (current_poll_owner) = poll_owner_public_key.read(poll_id=poll_id)

    assert_not_zero(current_poll_owner)

    let (sig_len : felt, sig : felt*) = get_tx_signature()

    assert sig_len = 2

    # Verify validity of Signature
    let (message) = hash2{hash_ptr=pedersen_ptr}(x=poll_id, y=voter_public_key)
    verify_ecdsa_signature(
        message=message, public_key=current_poll_owner, signature_r=sig[0], signature_s=sig[1])

    registered_voters.write(poll_id=poll_id, voter_public_key=voter_public_key, value=1)
    return ()
end

@view
func get_voting_state{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        poll_id : felt) -> (n_no_votes : felt, n_yes_votes : felt):
    let (n_no_votes) = voting_state.read(poll_id=poll_id, answer=0)
    let (n_yes_votes) = voting_state.read(poll_id=poll_id, answer=1)

    return (n_no_votes=n_no_votes, n_yes_votes=n_yes_votes)
end

@view
func get_is_voter_registered{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        poll_id : felt, voter_public_key : felt) -> (result : felt):
    # Read from registered_voters and verify that the voter is registered.
    let (is_voter_registered) = registered_voters.read(
        poll_id=poll_id, voter_public_key=voter_public_key)

    return (result=is_voter_registered)
end

func verify_vote{
        pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, ecdsa_ptr : SignatureBuiltin*,
        range_check_ptr}(poll_id : felt, voter_public_key : felt, vote : felt, r : felt, s : felt):
    # Verify the vote value is legal, i.e. 0 or 1
    assert (vote - 1) * (vote - 0) = 0

    # Read from registered_voters and verify that the voter is registered.
    let (is_voter_registered) = get_is_voter_registered(poll_id, voter_public_key)

    assert is_voter_registered = 1

    # Read from voter_state and verify that the voter has not voted for this poll yet.
    let (has_voter_voted) = voter_state.read(poll_id=poll_id, voter_public_key=voter_public_key)

    assert has_voter_voted = 0

    # Verify the validity of the signature. The hash should be on the poll_id and the vote.
    let (message) = hash2{hash_ptr=pedersen_ptr}(x=poll_id, y=vote)

    verify_ecdsa_signature(
        message=message, public_key=voter_public_key, signature_r=r, signature_s=s)

    return ()
end

@external
func vote{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,
        ecdsa_ptr : SignatureBuiltin*}(poll_id : felt, voter_public_key : felt, vote : felt):
    let (sig_len : felt, sig : felt*) = get_tx_signature()

    assert sig_len = 2

    # Verify Vote
    verify_vote(poll_id=poll_id, voter_public_key=voter_public_key, vote=vote, r=sig[0], s=sig[1])

    # Vote.
    let (current_n_votes) = voting_state.read(poll_id, answer=vote)

    voting_state.write(poll_id=poll_id, answer=vote, value=current_n_votes + 1)
    voter_state.write(poll_id=poll_id, voter_public_key=voter_public_key, value=1)
    return ()
end

@external
func finalize_poll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        poll_id : felt) -> (result : felt):
    alloc_locals
    let (local result_recorder_address) = result_recorder.read()

    let (n_no_votes, n_yes_votes) = get_voting_state(poll_id=poll_id)

    # Store these references in local variables as they might be revoked by is_le().
    local syscall_ptr : felt* = syscall_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr
    let (result) = is_le(n_no_votes, n_yes_votes)

    # Demonstrate Cairo short strings. "Yes" == int.from_bytes("Yes".encode("ascii"), "big").
    let result = (result * 'Yes') + ((1 - result) * 'No')

    let (recorder_result) = ResultRecorder.get_poll_result(
        contract_address=result_recorder_address, poll_id=poll_id)

    assert recorder_result = 0

    # Record the poll result in ResultRecorder contract
    ResultRecorder.record(contract_address=result_recorder_address, poll_id=poll_id, result=result)
    return (result=1)
end

# Result Recorder Interface
@contract_interface
namespace ResultRecorder:
    func record(poll_id : felt, result : felt):
    end

    func get_poll_result(poll_id : felt) -> (result : felt):
    end
end
