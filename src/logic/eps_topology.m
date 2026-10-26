function topo = eps_topology()
%EPS_TOPOLOGY  Nodes and contactors of the 270 V DC distribution system.
%
%        GEN1           APU            GEN2
%          |GLC1         |ALC            |GLC2
%         HV1 --BTC1--- TIE ---BTC2--- HV2 ---[INV]--- AC 115 V
%          |EFC1                         |EFC2
%          +------------ HVE ------------+
%                         |  \
%                    BLC  |   [DCDC-A, DCDC-B]
%                 BATT/BCRU    |
%                             LV 28 V
%
%   Sources are graph nodes 1..4, buses 5..8. Each contactor is an edge.
%   The 28 V and AC buses hang off converters, not contactors, so they are
%   handled separately in the power-flow code.

topo.nodes   = {'GEN1', 'GEN2', 'APU', 'BATT', 'HV1', 'TIE', 'HV2', 'HVE'};
topo.sources = {'GEN1', 'GEN2', 'APU', 'BATT'};
topo.buses   = {'HV1', 'TIE', 'HV2', 'HVE'};
topo.contactors = {'GLC1', 'GLC2', 'ALC', 'BTC1', 'BTC2', 'EFC1', 'EFC2', 'BLC'};
topo.edges = [1 5;    % GLC1  GEN1 - HV1
              2 7;    % GLC2  GEN2 - HV2
              3 6;    % ALC   APU  - TIE
              5 6;    % BTC1  HV1  - TIE
              6 7;    % BTC2  TIE  - HV2
              5 8;    % EFC1  HV1  - HVE
              7 8;    % EFC2  HV2  - HVE
              4 8];   % BLC   BATT - HVE
end
