function test_transient_envelope()
%TEST_TRANSIENT_ENVELOPE  REQ-PQ-02/03: load application, load rejection and
%   a soft-start bus transfer stay inside the MIL-STD-704F normal transient
%   envelope, and the transfer interruption is no longer than 50 ms.
%   Also checks that the envelope checker itself catches a violation.
r = study_transients(transient_params(), '');
assert(r.application.pass, 'Load application violates the transient envelope');
assert(r.rejection.pass, 'Load rejection violates the transient envelope');
assert(r.transfer_soft.pass, 'Soft-start bus transfer fails the envelope or the 50 ms limit');
assert(r.transfer_soft.interruption_s <= 0.050, 'Transfer interruption longer than 50 ms');
% documented finding: without soft start the recovery overshoots
assert(~r.transfer_hard.envelope_ok, 'Expected the hard transfer to overshoot (documented finding)');

% checker sanity: a 340 V spike at 5 ms must fail, a 320 V spike must pass
lim = mil704_limits();
t = 0:1e-4:0.2;
v = 270 * ones(size(t));
v(t > 0.005 & t < 0.006) = 340;
c = check_transient_envelope(t, v, 0, lim.hv);
assert(~c.pass, 'Envelope checker missed a 340 V overvoltage');
v(t > 0.005 & t < 0.006) = 320;
c = check_transient_envelope(t, v, 0, lim.hv);
assert(c.pass, 'Envelope checker rejected a 320 V transient inside the envelope');
end
