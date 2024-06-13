//SPDx-License-Identifier: MIT

pragma solidity ^0.8.18;



/**
 * @author  Hamza
 * @title   A simple raffle contract
 * @dev     Implements Chainlink VRFv2 for random number generation
 * @notice  This contract is for creating a raffle
 */

contract Raffle{
    error Raffle__NotEnoughEthSent();

    /**State Variables */
    uint256 private constant REQUEST_CONFIRMATION = 2;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    //@dev Duration of the lottery in seconds
    uint256 private immutable i_interval;
    address private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    

    /**Events */
    event EnterRaffle(address indexed player);


    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator,
    bytes32 keyHash, uint256 subscriptionId,uint32 callbackGasLimit){
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_entranceFee = entranceFee;
        i_vrfCoordinator = vrfCoordinator;
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable{
        if(msg.value < i_entranceFee){
            revert Raffle__NotEnoughEthSent();
        }
        s_players.push(payable(msg.sender));

        emit EnterRaffle(msg.sender);
    }

    function pickWinner() external {
        if((block.timestamp - s_lastTimeStamp) < i_interval){
            revert();
        }
         uint256 requestId = i_vrfCoordinator.requestRandomWords(
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

    /** Getter Function */

    function getEntranceFee() public view returns(uint256){
        return i_entranceFee;
    }
}