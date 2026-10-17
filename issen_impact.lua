-- Issen Impact: observes impact callbacks; never changes combat values.
local cfg = { enabled=true, sound=true, rumble=true, volume=1.0, strength=1.0, duration_ms=80 }
local config_path='issen_impact_config.json'
local loaded_ok,saved=pcall(json.load_file,config_path)
if loaded_ok and type(saved)=='table' then
    for key,value in pairs(cfg) do
        if type(saved[key])==type(value) then cfg[key]=saved[key] end
    end
end
cfg.volume=math.max(0,math.min(1,cfg.volume))
cfg.strength=math.max(0,math.min(1,cfg.strength))
cfg.duration_ms=math.floor(math.max(40,math.min(220,cfg.duration_ms)))
local seq, frame, last, pending = 0, 0, -100, false
local session = tostring(os.time()) .. ':' .. tostring(os.clock())
local status = 'Waiting for player'
-- GRAPPLE also covers non-Issen actions; require an explicit Issen action.
local GRAPPLE_STATE=524288
local action_name='not observed yet'
local action_owner=nil
local function is_issen_action(name)
    if type(name)~='string' then return false end
    local family,leaf=name:match('^app%.(Player[%a]+Action)%.(c[%w_]+)$')
    if family~='PlayerOneHandedAction' and family~='PlayerTwoHandedAction'
        and family~='PlayerCommonAction' then return false end
    return leaf:match('^cCounterIssen')~=nil or leaf:match('^cBlockIssen')~=nil
        or leaf:match('^cBreakIssen')~=nil or leaf:match('^cChainIssen')~=nil
end
local audit, audit_seq, audit_dirty={},0,false
local last_audit_frame=-100
local function record(kind,extra)
    audit_seq=audit_seq+1
    local row={seq=audit_seq,frame=frame,kind=kind,action=action_name}
    for key,value in pairs(extra or {}) do row[key]=value end
    audit[#audit+1]=row
    if #audit>256 then table.remove(audit,1) end
    audit_dirty=true
end
local function publish(test)
    seq = seq + 1
    json.dump_file('issen_impact_event.json', {
        session=session, seq=seq, sound=cfg.sound, rumble=cfg.rumble,
        volume=cfg.volume, strength=cfg.strength, duration_ms=cfg.duration_ms, test=test or false,
        action=action_name, trigger=test and 'ui_test' or 'attackBreakImpactNotice'
    })
end
local function is_player(entity)
    local manager=sdk.get_managed_singleton('app.PlayerManager')
    local info=manager and manager:call('getControllingPlayer')
    local player=info and info:call('get_CharacterEntity')
    local character=info and info:call('get_Character')
    return player and entity and player:get_address()==entity:get_address(), character
end
local action_td=sdk.find_type_definition('app.CharacterBase')
local action_method=action_td and action_td:get_method('evBaseActionEnter')
if action_method then
    sdk.hook(action_method,function(args)
        pcall(function()
            local manager=sdk.get_managed_singleton('app.PlayerManager')
            local info=manager and manager:call('getControllingPlayer')
            local character=info and info:call('get_Character')
            local owner=sdk.to_managed_object(args[2])
            if not character or not owner or character:get_address()~=owner:get_address() then return end
            local action=sdk.to_managed_object(args[3])
            local definition=action and action:get_type_definition()
            action_name=definition and definition:get_full_name() or 'unknown'
            action_owner=character:get_address()
            record('action_enter')
        end)
    end,function(retval) return retval end)
end
local td=sdk.find_type_definition('app.cPlayerCharacterEntity')
local method=td and td:get_method('attackBreakImpactNotice')
if method then
    sdk.hook(method,function(args)
        if not cfg.enabled then return end
        local ok,err=pcall(function()
            local own,character=is_player(sdk.to_managed_object(args[2]))
            if own and character then
                local bits=character:call('getActionState')
                record('impact',{state_bits=bits,grapple=(bits & GRAPPLE_STATE)~=0})
            end
            local accepted=own and character and action_owner==character:get_address()
                and is_issen_action(action_name)
            if own and character and not accepted then record('impact_rejected') end
            if accepted and (character:call('getActionState') & GRAPPLE_STATE)~=0
                and frame-last>10 then
                last=frame
                pending=true
                record('sound_trigger')
            end
        end)
        if not ok then status=tostring(err) end
    end,function(retval) return retval end)
    status='Impact hook ready (attackBreakImpactNotice)'
else
    status='Unsupported game version: impact hook missing'
    log.error('[IssenImpact] '..status)
end
re.on_frame(function()
    frame=frame+1
    if pending then
        pending=false
        local ok,err=pcall(publish,false)
        if not ok then status=tostring(err) end
    end
    if audit_dirty and frame-last_audit_frame>=30 then
        last_audit_frame=frame
        local ok=pcall(json.dump_file,'issen_impact_audit.json',{session=session,records=audit})
        if ok then audit_dirty=false end
    end
end)
re.on_draw_ui(function()
    if imgui.tree_node('Issen Impact - DS4') then
        imgui.text(status)
        imgui.text('Issen-only filter v2 (DeadHeat excluded)')
        imgui.text('Events sent: '..tostring(seq))
        imgui.text('Last action: '..action_name)
        imgui.text('Trigger scope verification: recording')
        local changed,dirty=false,false
        changed,cfg.enabled=imgui.checkbox('Enabled##IssenImpact',cfg.enabled)
        dirty=dirty or changed
        changed,cfg.sound=imgui.checkbox('Sound##IssenImpact',cfg.sound)
        dirty=dirty or changed
        changed,cfg.volume=imgui.slider_float('Sound volume##IssenImpact',cfg.volume,0,1)
        dirty=dirty or changed
        changed,cfg.rumble=imgui.checkbox('Rumble##IssenImpact',cfg.rumble)
        dirty=dirty or changed
        changed,cfg.strength=imgui.slider_float('Strength##IssenImpact',cfg.strength,0,1)
        dirty=dirty or changed
        changed,cfg.duration_ms=imgui.slider_int('Duration ms##IssenImpact',cfg.duration_ms,40,220)
        dirty=dirty or changed
        if dirty then
            local ok,err=pcall(json.dump_file,config_path,cfg)
            if not ok then status='Config save failed: '..tostring(err) end
        end
        imgui.text('Changes are saved. The companion must be running.')
        if imgui.button('Test sound + rumble##IssenImpact') then
            local ok,err=pcall(publish,true)
            if not ok then status=tostring(err) end
        end
        imgui.tree_pop()
    end
end)
