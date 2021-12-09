# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func poll_result(poll_id : felt) -> (result : felt):
end

@external
func record{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        poll_id : felt, result : felt):
    poll_result.write(poll_id=poll_id, value=result)
    return ()
end

@view
func get_poll_result{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        poll_id : felt) -> (result : felt):
    let (result) = poll_result.read(poll_id=poll_id)
    return (result=result)
end
