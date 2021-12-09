import random
from typing import Tuple
from starkware.crypto.signature.signature import pedersen_hash, private_to_stark_key, sign


def generate_key_pair() -> Tuple[int, int]:
    private_key = random.randrange(1 << 251)
    public_key = private_to_stark_key(private_key)
    return (private_key, public_key)


def sign_voter_registration(
    poll_id: int, voter_public_key: int, owner_private_key: int
) -> Tuple[int, int]:
    r, s = sign(msg_hash=pedersen_hash(poll_id, voter_public_key),
                priv_key=owner_private_key)
    return (r, s)


def sign_vote(poll_id: int, vote: int, private_key: int) -> Tuple[int, int]:
    r, s = sign(msg_hash=pedersen_hash(poll_id, vote), priv_key=private_key)
    return (r, s)


# if __name__ == '__main__':
#     (private_key, public_key) = generate_key_pair()
#     print("Private Key={}, \nPublic Key={}".format(private_key, public_key))
