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
local eIndex = 0;
local eIndexFix = 0;

for sIndex=0, Doc:GetDictionary():GetNumSections()-1,1 do
  local Section = Doc:GetDictionary():GetLanguage(sIndex);
  for lIndex=0,Section:GetNumEntries()-1,1 do
    Entry = Section:GetEntry(lIndex);
    eIndexFix = 0;
    for eIndex=0,Entry:GetNumDescendantsOfElementType(ElementAudioBank:GetID())-1,1 do
      local AudioBank = Entry:GetNthDescendantOfElementType(ElementAudioBank:GetID(),eIndex - eIndexFix);
      if AudioBank:GetNumChildrenOfElementType(ElementAudio:GetID()) == 0 and tRequestModify(Entry, true) then
        AudioBank:PreDeleteFromDoc();
        Doc:DeleteTreeFromDoc(AudioBank);
        eIndexFix = eIndexFix + 1;
        if Entry:HasChanged() == false then
          Entry:SetChanged(true,true);
        end
      end
    end
  end
end

Doc:SetDirty();
return "success";
