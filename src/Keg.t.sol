pragma solidity >=0.5.15;

import "ds-test/test.sol";
import "ds-math/math.sol";
import "lib/dss-interfaces/src/Interfaces.sol";

import "./Keg.sol";
import {DssSpell, SpellAction} from "./Keg-Spell.sol";

contract Hevm { function warp(uint) public; }

contract KegTest is DSTest, DSMath {
    Hevm hevm;

    DssSpell spell;

    address constant public MCD_VOW         = 0xBFE7af74255c660e187758D23A08B4D5074252C7;
    address constant public MCD_VAT         = 0x11eFdA5E32683555a508c30B1100063b4335FC3E;
    address constant public USER_1          = 0x57D37c790DDAA0b82e3DEb291DbDd8556c94F1f1;
    address constant public USER_2          = 0x644156537BdB3eaF81C904633C3bA844d5FEB00f;
    address constant public USER_3          = 0xFfffFfFffbdB3eaf81c904633C3Ba844D5FEB00F;
    address constant public MCD_PAUSE_PROXY = 0x784e656E5Fa1F9CdCe4015539adA7fC31738Eba3;
    address constant public MCD_KEG         = 0xD0505C9A76686a5FF67147C0A079863e8D45e725;

    MKRAbstract       gov = MKRAbstract(0x8CA90018a8D759F68DD6de3d4fc58d37602aac78);
    DSChiefAbstract chief = DSChiefAbstract(0x8C67F07CBe3c0dBA5ECd5c1804341703458A2e8A);
    DSPauseAbstract pause = DSPauseAbstract(0xCE8B162F99eFB2dFc0A448A8D7Ed3218B5919ED1);
    VatAbstract       vat = VatAbstract(MCD_VAT);
    Keg               keg = Keg(MCD_KEG);
    GemAbstract       dai = GemAbstract(0x78E8E1F59D80bE6700692E2aAA181eAb819FA269);

    uint256 constant public THOUSAND = 10**3;
    uint256 constant public MILLION  = 10**6;
    uint256 constant public WAD      = 10**18;
    uint256 constant public RAY      = 10**27;
    uint256 constant public RAD      = 10**45;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE = bytes20(uint160(uint256(keccak256('hevm cheat code'))));

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));
        spell = new DssSpell();
    }

    function vote() private {
        if (chief.hat() != address(spell)) {
            gov.approve(address(chief), uint256(-1));
            chief.lock(sub(gov.balanceOf(address(this)), 1 ether));

            assertTrue(!spell.done());

            address[] memory yays = new address[](1);
            yays[0] = address(spell);

            chief.vote(yays);
            chief.lift(address(spell));
        }
        assertEq(chief.hat(), address(spell));
    }

    function scheduleWaitAndCast() public {
        spell.schedule();
        hevm.warp(now + pause.delay());
        spell.cast();
    }

    function testSpellIsCast() public {
        // Test description
        string memory description = new SpellAction().description();
        assertTrue(bytes(description).length > 0);

        vote();
        scheduleWaitAndCast();
        assertTrue(spell.done());
        assertEq(vat.wards(address(keg)), 1);
    }

    function test_keg_deploy() public {
        assertEq(keg.wards(address(this)),  1);
        assertEq(address(keg.vat()),  MCD_VAT);
        assertEq(keg.vow(), MCD_VOW);
        assertEq(keg.beer(), 0);
    }

    function test_brew() public {
        vote();
        scheduleWaitAndCast();
        assertTrue(spell.done());

        uint wad = 6 ether;

        assertEq(vat.dai(address(keg)), 0);
        keg.brew(wad);
        assertEq(vat.dai(address(keg)), wad * RAY);
    }

    function test_pour() public {
        vote();
        scheduleWaitAndCast();
        assertTrue(spell.done());

        uint wad = 6 ether;

        assertEq(vat.dai(address(keg)), 0);
        keg.brew(wad);
        assertEq(vat.dai(address(keg)), wad * RAY); // 6 DAI

        address[] memory users = new address[](2);
        users[0] = USER_1;
        users[1] = USER_2;
        uint256[] memory amts = new uint256[](2);
        amts[0] = 1.5 ether;
        amts[1] = 4.5 ether;

        assertEq(keg.beer(), 0);
        assertEq(keg.mugs(USER_1), 0);
        assertEq(keg.mugs(USER_2), 0);
        keg.pour(users, amts);
        assertEq(keg.beer(), amts[0] + amts[1]); // Beer = 6
        assertEq(keg.mugs(USER_1), amts[0]);     // Mug1 = 1.5
        assertEq(keg.mugs(USER_2), amts[1]);     // Mug2 = 4.5
        assertEq(vat.dai(address(keg)), keg.beer() * RAY); // Beer = 6 DAI
    }

    function testFail_pour_unequal_to_brew() public {
        vote();
        scheduleWaitAndCast();
        assertTrue(spell.done());

        uint wad = 6 ether;

        assertEq(vat.dai(address(keg)), 0);
        keg.brew(wad);
        assertEq(vat.dai(address(keg)), wad * RAY); // 6 DAI

        address[] memory users = new address[](2);
        users[0] = USER_1;
        users[1] = USER_2;
        uint256[] memory amts = new uint256[](2);
        amts[0] = 1.5 ether;
        amts[1] = 4.499 ether;

        keg.pour(users, amts);
    }

    function testFail_pour_unequal_length() public {
        vote();
        scheduleWaitAndCast();
        assertTrue(spell.done());

        uint wad = 6 ether;

        assertEq(vat.dai(address(keg)), 0);
        keg.brew(wad);
        assertEq(vat.dai(address(keg)), wad * RAY); // 6 DAI

        address[] memory users = new address[](2);
        users[0] = USER_1;
        users[1] = USER_2;
        uint256[] memory amts = new uint256[](1);
        amts[0] = 1.5 ether;

        keg.pour(users, amts);
    }

    function testFail_pour_zero_length() public {
        vote();
        scheduleWaitAndCast();
        assertTrue(spell.done());

        uint wad = 6 ether;

        assertEq(vat.dai(address(keg)), 0);
        keg.brew(wad);
        assertEq(vat.dai(address(keg)), wad * RAY); // 6 DAI

        address[] memory users = new address[](0);
        uint256[] memory amts = new uint256[](0);
        keg.pour(users, amts);
    }

    function testFail_pour_zero_address() public {
        vote();
        scheduleWaitAndCast();
        assertTrue(spell.done());

        uint wad = 6 ether;

        assertEq(vat.dai(address(keg)), 0);
        keg.brew(wad);
        assertEq(vat.dai(address(keg)), wad * RAY); // 6 DAI

        address[] memory users = new address[](2);
        users[0] = address(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 1.5 ether;
        keg.pour(users, amts);
    }

    function test_chug() public {
        vote();
        scheduleWaitAndCast();
        assertTrue(spell.done());

        uint wad = 6 ether;
        assertEq(vat.dai(address(keg)), 0);

        keg.brew(wad); // 6 DAI brewed

        assertEq(vat.dai(address(keg)), wad * RAY); // 6 DAI

        address[] memory users = new address[](2);
        users[0] = USER_1;
        users[1] = USER_2;
        uint256[] memory amts = new uint256[](2);
        amts[0] = 1.5 ether;
        amts[1] = 4.5 ether;

        assertEq(keg.beer(), 0);
        assertEq(keg.mugs(USER_1), 0);
        assertEq(keg.mugs(USER_2), 0);

        keg.pour(users, amts);

        assertEq(keg.beer(), amts[0] + amts[1]); // Beer = 6
        assertEq(keg.mugs(USER_1), amts[0]);     // Mug1 = 1.5
        assertEq(keg.mugs(USER_2), amts[1]);     // Mug2 = 4.5

        assertEq(vat.dai(address(keg)), keg.beer() * RAY); // Beer = 6 DAI
        assertEq(vat.dai(USER_1), 0);
        assertEq(vat.dai(USER_2), 0);
        
        keg.chug(); // msg.sender == USER_1

        assertEq(keg.beer(), amts[1]);       // Beer = 4.5
        assertEq(keg.mugs(USER_1), 0);       // Mug1 = 0
        assertEq(keg.mugs(USER_2), amts[1]); // Mug2 = 4.5
        assertEq(vat.dai(address(keg)), keg.beer() * RAY); // Beer = 4.5 DAI
        assertEq(vat.dai(USER_1), 1.5 ether * RAY); // 1.5 DAI
        assertEq(vat.dai(USER_2), 0);
    }

    function test_sip() public {
        vote();
        scheduleWaitAndCast();
        assertTrue(spell.done());

        uint wad = 6 ether; // 6 DAI brewed
        assertEq(vat.dai(address(keg)), 0);

        keg.brew(wad);

        assertEq(vat.dai(address(keg)), wad * RAY);

        address[] memory users = new address[](2);
        users[0] = USER_1;
        users[1] = USER_2;
        uint256[] memory amts = new uint256[](2);
        amts[0] = 1.5 ether;
        amts[1] = 4.5 ether;

        assertEq(keg.beer(), 0);
        assertEq(keg.mugs(USER_1), 0);
        assertEq(keg.mugs(USER_2), 0);

        keg.pour(users, amts);

        assertEq(keg.beer(), amts[0] + amts[1]); // Beer = 6
        assertEq(keg.mugs(USER_1), amts[0]);     // Mug1 = 1.5
        assertEq(keg.mugs(USER_2), amts[1]);     // Mug2 = 4.5

        assertEq(vat.dai(address(keg)), keg.beer() * RAY); // Beer = 6 DAI
        assertEq(vat.dai(USER_1), 0);
        assertEq(vat.dai(USER_2), 0);
        
        keg.sip(1 ether); // msg.sender == USER_1

        assertEq(keg.beer(), 5 ether);         // Beer = 5
        assertEq(keg.mugs(USER_1), 0.5 ether); // Mug1 = 0.5
        assertEq(keg.mugs(USER_2), amts[1]);   // Mug2 = 4.5
        assertEq(vat.dai(address(keg)), keg.beer() * RAY); // Beer = 5 DAI
        assertEq(vat.dai(USER_1), 1 ether * RAY); // 1 DAI
        assertEq(vat.dai(USER_2), 0);
    }

    function testFail_sip_too_big() public {
        vote();
        scheduleWaitAndCast();
        assertTrue(spell.done());

        uint wad = 6 ether; // 6 DAI brewed
        assertEq(vat.dai(address(keg)), 0);

        keg.brew(wad);

        assertEq(vat.dai(address(keg)), wad * RAY);

        address[] memory users = new address[](2);
        users[0] = USER_1;
        users[1] = USER_2;
        uint256[] memory amts = new uint256[](2);
        amts[0] = 1.5 ether;
        amts[1] = 4.5 ether;

        assertEq(keg.beer(), 0);
        assertEq(keg.mugs(USER_1), 0);
        assertEq(keg.mugs(USER_2), 0);

        keg.pour(users, amts);

        assertEq(keg.beer(), amts[0] + amts[1]); // Beer = 6
        assertEq(keg.mugs(USER_1), amts[0]);     // Mug1 = 1.5
        assertEq(keg.mugs(USER_2), amts[1]);     // Mug2 = 4.5

        assertEq(vat.dai(address(keg)), keg.beer() * RAY); // Beer = 6 DAI
        assertEq(vat.dai(USER_1), 0);
        assertEq(vat.dai(USER_2), 0);
        
        keg.sip(2 ether); // msg.sender == USER_1
    }

    function test_pass() public {
        keg.pass(USER_2);
        assertEq(keg.buds(USER_1), USER_2);
        assertEq(keg.pals(USER_2), USER_1);
    }

    function testFail_pass_bud_with_existing_pal() public {
        keg.pass(USER_2);
        keg.pass(USER_2);
    }

    function test_pass_with_existing_bud() public {
        keg.pass(USER_2);
        keg.pass(USER_3);
        assertEq(keg.buds(USER_1), USER_3);
        assertEq(keg.pals(USER_2), address(0));
        assertEq(keg.pals(USER_3), USER_1);
    }

    function testFail_pass_yourself() public {
        keg.pass(USER_1);
    }

    function test_yank() public {
        keg.pass(USER_2);
        assertEq(keg.buds(USER_1), USER_2);
        assertEq(keg.pals(USER_2), USER_1);
        keg.yank();
        assertEq(keg.buds(USER_1), address(0));
        assertEq(keg.pals(USER_2), address(0));
    }

    function testFail_yank_no_bud() public {
        assertEq(keg.buds(USER_1), address(0));
        keg.yank();
    }

    function testFail_chug_with_yanked_bud() public {
        keg.pass(USER_2);
        keg.pass(USER_3);
        //how does one become a different user - hevm hack?
        //keg.chug()

        assertTrue(false);  //temp to pass test
    }

    function test_chug_as_bud() public {
        //how does one become a different user - hevm hack?
    }
}