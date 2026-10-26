function v = battery_ocv(b, soc)
%BATTERY_OCV  Cell open-circuit voltage [V] from the OCV-SOC table.
v = interp_lin(b.soc_tab, b.ocv_tab, min(max(soc, 0), 1));
end
