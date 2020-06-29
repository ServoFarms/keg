// Copyright (C) 2020 Maker Ecosystem Growth Holdings, INC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.5.15;

import "lib/dss-interfaces/src/dapp/DSPauseAbstract.sol";
import "lib/dss-interfaces/src/dss/VatAbstract.sol";
import "lib/dss-interfaces/src/dss/CatAbstract.sol";
import "lib/dss-interfaces/src/dss/JugAbstract.sol";
import "lib/dss-interfaces/src/dss/PotAbstract.sol";
import "lib/dss-interfaces/src/dss/GemJoinAbstract.sol";
import "lib/dss-interfaces/src/dss/FlipAbstract.sol";
import "lib/dss-interfaces/src/dss/SpotAbstract.sol";
import "lib/dss-interfaces/src/dss/OsmAbstract.sol";
import "lib/dss-interfaces/src/dss/OsmMomAbstract.sol";
import "./Keg.sol";

contract MedianAbstract {
    function kiss(address) public;
}

contract SpellAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    string constant public description = "Rely spell for Keg";

    // The contracts in this list should correspond to MCD core contracts, verify
    //  against the current release list at:
    //     https://changelog.makerdao.com/releases/mainnet/1.0.5/contracts.json
    //
    // Contract addresses pertaining to the SCD ecosystem can be found at:
    //     https://github.com/makerdao/sai#dai-v1-current-deployments
    address constant public DAI      = 0x78E8E1F59D80bE6700692E2aAA181eAb819FA269;
    address constant public DAI_JOIN = 0x42497e715a1e793a65E9c83FE813AfC677952e16; // Have not done rely/deny
    address constant public MCD_VOW  = 0xBFE7af74255c660e187758D23A08B4D5074252C7;
    address constant public MCD_VAT  = 0x11eFdA5E32683555a508c30B1100063b4335FC3E;
    address constant public MCD_KEG  = 0xD0505C9A76686a5FF67147C0A079863e8D45e725;

    uint256 constant public THOUSAND = 10**3;
    uint256 constant public MILLION  = 10**6;
    uint256 constant public WAD      = 10**18;
    uint256 constant public RAY      = 10**27;
    uint256 constant public RAD      = 10**45;

    // Many of the settings that change weekly rely on the rate accumulator
    // described at https://docs.makerdao.com/smart-contract-modules/rates-module
    // To check this yourself, use the following rate calculation (example 8%):
    //
    // $ bc -l <<< 'scale=27; e( l(1.08)/(60 * 60 * 24 * 365) )'
    //
    uint256 constant public ZERO_PCT_RATE = 1000000000000000000000000000;
    uint256 constant public ONE_PCT_RATE  = 1000000000315522921573372069;

    function execute() external {
        /* --- First Spell --- */
        // VatAbstract(MCD_VAT).rely(MCD_KEG);

        /* --- Second Spell --- */
        Keg keg = Keg(MCD_KEG);
        keg.brew(70 * WAD);

        address[] memory users = new address[](4);
        users[0] = 0x0048d6225D1F3eA4385627eFDC5B4709Cab4A21c;
        users[1] = 0x60Fd36AEfE398CcC77eca6219c26e80FF1185282;
        users[2] = 0x4554Ca72e7260cf88fC640a875f9477D5ADdB764;
        users[3] = 0x999E268cc9461c9ea8Bf88b92fB94CA3Bc19A975;
        uint256[] memory amts = new uint256[](4);
        amts[0] = 20 * WAD;
        amts[1] = 25 * WAD;
        amts[2] = 10 * WAD;
        amts[3] = 15 * WAD;

        keg.pour(users, amts);
    }
}

contract DssSpell {

    DSPauseAbstract  public pause =
        DSPauseAbstract(0xCE8B162F99eFB2dFc0A448A8D7Ed3218B5919ED1);
    address          public action;
    bytes32          public tag;
    uint256          public eta;
    bytes            public sig;
    uint256          public expiration;
    bool             public done;

    constructor() public {
        sig = abi.encodeWithSignature("execute()");
        action = address(new SpellAction());
        bytes32 _tag;
        address _action = action;
        assembly { _tag := extcodehash(_action) }
        tag = _tag;
        expiration = now + 30 days;
    }

    function description() public view returns (string memory) {
        return SpellAction(action).description();
    }

    function schedule() public {
        require(now <= expiration, "This contract has expired");
        require(eta == 0, "This spell has already been scheduled");
        eta = now + DSPauseAbstract(pause).delay();
        pause.plot(action, tag, sig, eta);
    }

    function cast() public {
        require(!done, "spell-already-cast");
        done = true;
        pause.exec(action, tag, sig, eta);
    }
}
