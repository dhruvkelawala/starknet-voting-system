"""Voting System Contract Test"""
# from inspect import signature
import os
import asyncio

import pytest
from starkware.starknet.testing.starknet import Starknet

from utils.signer import generate_key_pair, sign_voter_registration, sign_vote

VOTING_SYSTEM_CONTRACT = os.path.join('contracts', 'VotingSystem.cairo')
RESULT_RECORDER_CONTRACT = os.path.join('contracts', 'ResultRecorder.cairo')

PRIVATE_KEY, PUBLIC_KEY = generate_key_pair()
VOTER_PRIVATE_KEY, VOTER_PUBLIC_KEY = generate_key_pair()
VOTER_PRIVATE_KEY_2, VOTER_PUBLIC_KEY_2 = generate_key_pair()
POLL_ID = 1


@pytest.fixture(scope='module')  # Enables Modules
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
def get_keys():
    return generate_key_pair()


@pytest.fixture(scope="module")  # Fixture to save time during test
async def contract_factory():
    starknet = await Starknet.empty()
    result_recorder_contract = await starknet.deploy(RESULT_RECORDER_CONTRACT)
    voting_system_contract = await starknet.deploy(VOTING_SYSTEM_CONTRACT, constructor_calldata=[result_recorder_contract.contract_address])

    return starknet, voting_system_contract, result_recorder_contract


@pytest.mark.asyncio
async def test_init_poll(contract_factory):
    """INIT_POLL"""
    _, voting_system_contract, _ = contract_factory
    execution_info = await voting_system_contract.init_poll(poll_id=POLL_ID, public_key=PUBLIC_KEY).invoke()
    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_register_voter(contract_factory):
    """REGISTER_VOTER"""
    _, voting_system_contract, _ = contract_factory

    sig_r, sig_s = sign_voter_registration(
        POLL_ID, VOTER_PUBLIC_KEY, PRIVATE_KEY)

    await voting_system_contract.register_voter(poll_id=POLL_ID, voter_public_key=VOTER_PUBLIC_KEY).invoke(signature=[sig_r, sig_s])
    execution_info = await voting_system_contract.get_is_voter_registered(POLL_ID, VOTER_PUBLIC_KEY).call()
    assert execution_info.result == (1,)

    sig_r, sig_s = sign_voter_registration(
        POLL_ID, VOTER_PUBLIC_KEY_2, PRIVATE_KEY)

    await voting_system_contract.register_voter(poll_id=POLL_ID, voter_public_key=VOTER_PUBLIC_KEY_2).invoke(signature=[sig_r, sig_s])
    execution_info = await voting_system_contract.get_is_voter_registered(POLL_ID, VOTER_PUBLIC_KEY_2).call()
    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_vote(contract_factory):
    """VOTE"""
    _, voting_system_contract, _ = contract_factory

    """TEST WITH VOTE = 1"""
    vote = 1

    sig_r, sig_s = sign_vote(POLL_ID, vote, VOTER_PRIVATE_KEY)
    await voting_system_contract.vote(POLL_ID, VOTER_PUBLIC_KEY, vote).invoke(signature=[sig_r, sig_s])

    voting_state = await voting_system_contract.get_voting_state(POLL_ID).call()
    assert voting_state.result == (0, 1)

    vote = 0
    sig_r, sig_s = sign_vote(POLL_ID, vote, VOTER_PRIVATE_KEY_2)
    await voting_system_contract.vote(POLL_ID, VOTER_PUBLIC_KEY_2, vote).invoke(signature=[sig_r, sig_s])
    voting_state = await voting_system_contract.get_voting_state(POLL_ID).call()
    assert voting_state.result == (1, 1)


@pytest.mark.asyncio
async def test_finalize_poll(contract_factory):
    """FINALIZE POLL"""
    _, voting_system_contract, _ = contract_factory

    execution_info = await voting_system_contract.finalize_poll(POLL_ID).invoke()

    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_get_poll_results_from_recorder(contract_factory):
    """POLL RESULTS FROM RECORDER"""

    _, _, result_recorder_contract = contract_factory

    poll_results = await result_recorder_contract.get_poll_result(POLL_ID).call()

    print("Poll results = ", poll_results.result)

    assert poll_results.result == (5858675,)
