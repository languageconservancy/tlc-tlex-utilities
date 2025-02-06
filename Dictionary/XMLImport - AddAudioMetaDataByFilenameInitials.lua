-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton


--Include Utility Functions
tRequestLoadAll();
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
local countEdits = 0;
local Speakers = {};
Speakers["_INITIALS_"] = {"Full Name","M/F",""}; --Name, Gender, IsStudent/L2/Dialect


for sIndex=0, Doc:GetDictionary():GetNumSections()-1,1 do
  local Section = Doc:GetDictionary():GetLanguage(sIndex);
  for lIndex=0,Section:GetNumEntries()-1,1 do
    Entry = Section:GetEntry(lIndex);
    if tFrameWindow():GetSectionWindow(Section):IsTagged(Entry) then
      for eIndex =0, Entry:GetNumDescendantsOfElementType(ElementAudio:GetID())-1, 1 do
        local Audio = Entry:GetNthDescendantOfElementType(ElementAudio:GetID(),eIndex);
        local filePath = Audio:GetAttributeDisplayAsString(AttrFilePath);
        local speakerName = tQuery(Audio,"/@Speaker");
        if speakerName == nil or speakerName == "" then
          if tRequestModify(Entry, true) then
            if filePath ~= nil and filePath ~= "" then
              for key,value in pairs(Speakers) do
                if string.match(filePath,key) then
                  Audio:SetAttributeDisplayByString(AttrSpeaker,value[1]);
                  Audio:SetAttributeDisplayByString(AttrGender,value[2]);
                  Audio:SetAttributeDisplayByString(AttrIsStudent,value[3]);
                  if Entry:HasChanged() == false then
                    Entry:SetChanged(true,true);
                  end
                  countEdits = countEdits + 1;
                end
              end
            end
          end
        end
      end
    end
  end
end

Doc:SetDirty();
return "edits: "..countEdits;