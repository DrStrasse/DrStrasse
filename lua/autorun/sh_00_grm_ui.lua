-- GRM UI lifecycle guard.  All GRM windows use a stable key so repeated
-- network messages/console commands cannot leave identical dialogs stacked.
GRM = GRM or {}
GRM.UI = GRM.UI or {}

function GRM.UI.Track(key, panel)
    if not key or not panel then return panel end
    local frames = GRM.UI._frames or {}
    GRM.UI._frames = frames
    local old = frames[key]
    if IsValid(old) and old ~= panel then old:Remove() end
    frames[key] = panel
    local previous = panel.OnRemove
    panel.OnRemove = function(self)
        if previous then previous(self) end
        if frames[key] == self then frames[key] = nil end
    end
    return panel
end

function GRM.UI.Close(key)
    local frames = GRM.UI._frames or {}
    local panel = frames[key]
    if IsValid(panel) then panel:Remove() end
    if frames[key] == panel then frames[key] = nil end
end

function GRM.UI.IsOpen(key)
    return IsValid(GRM.UI._frames and GRM.UI._frames[key])
end

print("[GRM UI] lifecycle guard loaded")
