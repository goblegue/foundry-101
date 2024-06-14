//SPDx-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.1.1/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts@1.1.1/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts@1.1.1/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
/**
 * @author  Hamza
 * @title   A simple raffle contract
 * @dev     Implements Chainlink VRFv2 for random number generation
 * @notice  This contract is for creating a raffle
 */

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface{
    /**
     * Errors
     */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 players, RaffleState state);

    /**
     * Type declarations
     */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**
     * State Variables
     */
    uint16 private constant REQUEST_CONFIRMATION = 2;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    //@dev Duration of the lottery in seconds
    uint256 private immutable i_interval;
    // IVRFCoordinatorV2Plus private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentwinner;
    RaffleState private s_raffleState;

    /**
     * Events
     */
    event EnterRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_entranceFee = entranceFee;
        // i_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinator);
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));

        emit EnterRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /*data*/) public view override returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool timeHasPassed=(block.timestamp - s_lastTimeStamp) > i_interval;
        bool isOpen=s_raffleState == RaffleState.OPEN;
        bool hasPlayers=s_players.length > 0;
        bool hasBalance=address(this).balance > 0;

        upkeepNeeded = timeHasPassed && isOpen && hasPlayers && hasBalance;

        return (upkeepNeeded, "0x0");  
    }

    function performUpkeep(bytes calldata /*performData*/) external override{
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                s_raffleState
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATION,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
    }

    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override {
        // Use the random number to pick a winner
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recentwinner = winner;
        s_raffleState = RaffleState.OPEN;
        // Pay the winner
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }
    /**
     * Getter Function
     */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
