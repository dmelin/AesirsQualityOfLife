widgets, callbacks, learned, spellbook, trackingTypes, foods, itemSpells, descriptions = {}, {}, {}, {}, {}, {}, {}, {}
Enum={SpellBookSpellBank={Player=0}}
CLASS_ICON_TCOORDS={HUNTER={0,0.25,0.25,0.5}}
local methods={}
local function Guard() assert(not combat or secureClick, "insecure protected mutation during combat") end
function methods:SetSize() end
function methods:RegisterForClicks() end
function methods:SetNormalTexture() end
function methods:SetHighlightTexture() end
function methods:SetPoint(point, relative, relativePoint, x, y)
    Guard()
    if type(x)=="number" then
        self.x, self.y=x,y
        if relativePoint=="CENTER" and relative==UIParent then self.x,self.y=x+512,y+384 end
    end
end
function methods:CreateTexture() return setmetatable({}, {__index=methods}) end
function methods:CreateFontString() return setmetatable({}, {__index=methods}) end
function methods:SetTexture(value) self.texture=value end
function methods:SetTexCoord(...) self.coords={...} end
function methods:SetDesaturated(value) self.gray=value end
function methods:SetScript(key, fn) self.scripts[key]=fn end
function methods:RegisterEvent(event) self.registered[event]=true end
function methods:SetAttribute(key,value) Guard(); self.attributes[key]=value end
function methods:GetFrameRef(key) return self.refs[key] end
function methods:SetFrameRef(key,value) Guard(); self.refs[key]=value end
function methods:ClearAllPoints() Guard() end
function methods:SetAllPoints() Guard() end
function methods:Show() Guard(); self.shown=true end
function methods:Hide() Guard(); self.shown=false end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:SetMovable() end
function methods:SetClampedToScreen() end
function methods:SetFrameLevel() end
function methods:GetFrameLevel() return 5 end
function methods:SetBackdrop() end
function methods:SetBackdropColor() end
function methods:SetBackdropBorderColor() end
function methods:EnableMouse() end
function methods:RegisterForDrag() hunterMover=self end
function methods:SetText(text) self.text=text end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:GetCenter() return self.x,self.y end
function CreateFrame(kind,name,parent,template)
    local obj=setmetatable({name=name,parent=parent,template=template,shown=true,attributes={},refs={},scripts={},registered={}}, {__index=methods})
    if name then widgets[name]=obj; _G[name]=obj end
    if not name and not parent then hunterEvents=obj end
    return obj
end
UIParent=CreateFrame("Frame","MockUIParent")
EventRegistry={RegisterCallback=function(_,event,fn) callbacks[event]=fn end}
C_EditMode={GetLayouts=function() return {activeLayout=activeLayout or 3,layouts={{layoutType=2,layoutName=layoutName or "Test"}}} end}
function UnitExists() return hasPet~=false end
function UnitIsDeadOrGhost() return petDead end
function UnitLevel(unit) return unit=="pet" and (petLevel or 10) or 15 end
spellNames={[136]="Mend Pet",[6991]="Feed Pet",[883]="Call Pet",[982]="Revive Pet",[1515]="Tame Beast",
    [19705]="Well Fed",[13165]="Aspect of the Hawk",[13163]="Aspect of the Monkey",[5118]="Aspect of the Cheetah"}
C_Spell={GetSpellName=function(id) return spellNames[id] end,
    GetSpellInfo=function(id) return {iconID=id,name=spellNames[id]} end,
    GetSpellDescription=function(id) return descriptions[id] end}
C_SpellBook={IsSpellKnown=function(id) return learned[id] end,
    GetNumSpellBookSkillLines=function() return 1 end,
    GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=#spellbook} end,
    GetSpellBookItemInfo=function(slot) return spellbook[slot] end,
    IsSpellBookItemLowRank=function(slot) return spellbook[slot].lowRank end}
C_Minimap={GetNumTrackingTypes=function() return #trackingTypes end,GetTrackingInfo=function(i) return trackingTypes[i] end}
C_PetInfo={CanPetEatItem=function(id) return foods[id] and foods[id].edible end}
function C_Item.GetItemInfo(id)
    local d=foods[id]
    if not d or d.uncached then return end
    return d.name or ("Food "..id), "item:"..id, d.quality or 1,d.level or 10,d.required or 0,nil,nil,nil,nil,nil,d.price or 1
end
function C_Item.GetItemSpell(id) if itemSpells[id] then return "Eat",itemSpells[id] end end
function hevent(name)
    hunterEvents.scripts.OnEvent(hunterEvents,name)
end
function htick()
    hunterEvents.scripts.OnUpdate(hunterEvents,0.3)
end
function click(name)
    local obj=widgets[name]
    if obj.scripts.PreClick then obj.scripts.PreClick(obj) end
    local snippet=obj.attributes._onclick
    if snippet then
        secureClick=true
        loadstring("return function(self,button,down) "..snippet.." end")()(obj,"LeftButton",false)
        secureClick=false
    end
end
