//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 subscriptionId;
    address vrfCoordinatorV2_5;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 interval;
    LinkToken link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 1000 ether;

    event RaffleEntered(address indexed player);

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfigByChainId(block.chainid);
        entranceFee = networkConfig.raffleEntranceFee;
        interval = networkConfig.automationUpdateInterval;
        vrfCoordinatorV2_5 = networkConfig.vrfCoordinatorV2_5;
        gasLane = networkConfig.gasLane;
        subscriptionId = networkConfig.subscriptionId;
        callbackGasLimit = networkConfig.callbackGasLimit;
        link = LinkToken(networkConfig.link);

        vm.deal(PLAYER, STARTING_USER_BALANCE);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subscriptionId, LINK_BALANCE);
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
    }

    //Entry functions' tests
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsIfEntranceFeeNotMet() public {
        vm.startPrank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: 0}();
        vm.stopPrank();
    }

    function testRaffleRecordsPlayerOnEntry() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: raffle.getEntranceFee()}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
        vm.stopPrank();
    }

    function testRaffleEmitsEventOnEntrance() public {
        vm.startPrank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPlayerCannotEnterWhileRaffleIsCalculating() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
    }

    //Check Upkeep function tests
    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        //Arrange
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
        vm.stopPrank();
    }

    function testCheckUpkeepReturnsFalseIfNoPlayer() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreMet() public {
        //Arrange
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(upkeepNeeded);
        vm.stopPrank();
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        //Arrange
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
        vm.stopPrank();
    }

    //Perform Upkeep functions tests

    function testPerformUpkeepOnlyRunsIfCheckUpkeepIsTrue() public {
        //Arrange
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        raffle.performUpkeep("");

        //Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
        vm.stopPrank();
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        //Act & Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestedId = entries[1].topics[1];

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestedId) > 0);
        assert(uint256(raffleState) == 1);
    }

    //Fulfill Random Words Test

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerfomUpkeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        //Act/Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsTheRaffleAndSendsMoney() public raffleEntered skipFork {
        //Arrange
        uint256 additionalEntrants = 3; //Meaning we have a total of 4 participants
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        //We use the for loop to add the three new entrants to the raffle
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(1));
            hoax(newPlayer, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(uint256(requestId), address(raffle));

        //Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(expectedWinner == recentWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
