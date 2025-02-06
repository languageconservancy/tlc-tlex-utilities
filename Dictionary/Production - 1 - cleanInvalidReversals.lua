-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton

--make network compatible
tRequestLoadAll();

--Include Utility Functions
tLuaLog("Start");

function script_path()
  local script_paths = {};
  local str = debug.getinfo(2, "S").source:sub(2)
  script_paths['lang'] = str:match("(.*/)") or str:match("(.*[/\\])");
  script_paths['global'] = string.gsub(script_paths.lang,"[a-zA-Z ]+[/\\]$","");
  return script_paths
end
--load common functions
local report = "Report:\n";
local langCommonError = dofile(script_path().lang..'Common.lua');
if langCommonError ~= nil then
  return "langCommon Error: "..langCommonError
end
local globalCommonError = dofile(script_path().global..'Common.lua');
if globalCommonError ~= nil then
  return "globalCommon Error: "..globalCommonError
end

local lIndex = 0;
local sIndex = 0;
local eIndex = 0;
local eIndexFix = 0;
local count = 0;
for sIndex=0, Doc:GetDictionary():GetNumSections()-1,1 do
  local Section = Doc:GetDictionary():GetLanguage(sIndex);
  for lIndex=0,Section:GetNumEntries()-1,1 do
    local Entry = Section:GetEntry(lIndex);
    if tFrameWindow():GetSectionWindow(Section):IsTagged(Entry) then
      eIndexFix = 0;
      local revSenseCount = Entry:GetNumDescendantsOfElementType(ElementReversalSense:GetID());
      for eIndex=0,Entry:GetNumDescendantsOfElementType(ElementReversalSense:GetID())-1,1 do
        local RevSense = Entry:GetNthDescendantOfElementType(ElementReversalSense:GetID(),eIndex - eIndexFix);
        if RevSense ~= nil then
          
          tLuaLog(tQuery(RevSense,"/@Lemma"));
          tLuaLog(eIndexFix);
          if RevSense:GetNumDescendantsOfElementType(ElementReferences:GetID()) == 0 then
            recursiveDeleteEmptyUpChain(RevSense);
            eIndexFix = eIndexFix + 1;
            count = count + 1;
            if Entry:HasChanged() == false then
              Entry:SetChanged(true,true);
            end
          else
            if RevSense:GetNumChildrenOfElementType(ElementReferences:GetID()) > 0 then
              local ref = tolua.cast(RevSense:GetNthChildOfElementType(ElementReferences:GetID(),0),"tcReferences");
              if ref:GetNumRefEntries() > 0 then
                local RefSenseDef = ref:GetRefSense(ref:GetRefEntryID(0),0);
                --this is either Def or Sense
                if RefSenseDef == nil then
                  --just delete...not well formed
                  if RevSense:GetNumDescendantsOfElementType(ElementReferences:GetID()) == 1 then
                    if tRequestModify(Entry,true) then
                      recursiveDeleteEmptyUpChain(RevSense);
                      eIndexFix = eIndexFix + 1;
                      count = count + 1;
                      if Entry:HasChanged() == false then
                        Entry:SetChanged(true,true);
                      end
                    end
                  end
                else
                  --either TE is in Sense or Definitions
                  local TE = MatchTEWithinSense(Entry:GetLemmaSign(),RefSenseDef);
                  if TE ~= nil then
                    tLuaLog("TE exists");
                  else
                    if RevSense:GetNumDescendantsOfElementType(ElementReferences:GetID()) == 1 then
                      if tRequestModify(Entry,true) then
                        recursiveDeleteEmptyUpChain(RevSense);
                        eIndexFix = eIndexFix + 1;
                        count = count + 1;
                        if Entry:HasChanged() == false then
                          Entry:SetChanged(true,true);
                        end
                      end
                    end
                  end
                end
              else
                if RevSense:GetNumDescendantsOfElementType(ElementReferences:GetID()) == 1 then
                  if tRequestModify(Entry,true) then
                    recursiveDeleteEmptyUpChain(RevSense);
                    eIndexFix = eIndexFix + 1;
                    count = count + 1;
                    if Entry:HasChanged() == false then
                      Entry:SetChanged(true,true);
                    end
                  end
                end
              end
            end
            local sIndexFix = 0;
            for sIndex=0,RevSense:GetNumDescendantsOfElementType(ElementReversalDefinition:GetID())-1,1 do
              local RevDef = RevSense:GetNthDescendantOfElementType(ElementReversalDefinition:GetID(),sIndex - sIndexFix);
              if RevDef:GetNumChildrenOfElementType(ElementReferences:GetID()) > 0 then
                local ref = tolua.cast(RevDef:GetNthChildOfElementType(ElementReferences:GetID(),0),"tcReferences");
                if ref:GetNumRefEntries() > 0 then
                  local RefSenseDef = ref:GetRefSense(ref:GetRefEntryID(0),0);
                  --this is either Def or Sense
                  if RefSenseDef == nil then
                    --just delete...not well formed
                    if RevDef:GetNumChildren() == 1 then
                      if tRequestModify(Entry,true) then
                        recursiveDeleteEmptyUpChain(RevDef);
                        sIndexFix = sIndexFix + 1;
                        count = count + 1;
                        if Entry:HasChanged() == false then
                          Entry:SetChanged(true,true);
                        end
                      end
                    end
                    
                  else
                    --either TE is in Sense or Definitions
                    local TE = MatchTEWithinSense(Entry:GetLemmaSign(),RefSenseDef);
                    if TE ~= nil then
                      tLuaLog("TE exists");
                    else
                      if RevDef:GetNumChildren() == 1 then
                        if tRequestModify(Entry,true) then
                          recursiveDeleteEmptyUpChain(RevDef);
                          sIndexFix = sIndexFix + 1;
                          count = count + 1;
                          if Entry:HasChanged() == false then
                            Entry:SetChanged(true,true);
                          end
                        end
                      end
                    end
                  end
                else
                  if RevDef:GetNumChildren() == 1 then
                    if tRequestModify(Entry,true) then
                      recursiveDeleteEmptyUpChain(RevDef);
                      sIndexFix = sIndexFix + 1;
                      count = count + 1;
                      if Entry:HasChanged() == false then
                        Entry:SetChanged(true,true);
                      end
                    end
                  end
                end
              end
            end
          end
          eIndexFix = revSenseCount - Entry:GetNumDescendantsOfElementType(ElementReversalSense:GetID());
        end
      end
    end
  end
end

Doc:SetDirty();
return "deleted "..count;
