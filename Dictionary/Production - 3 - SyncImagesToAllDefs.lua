-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton

--Fix Yavapai Audios and Notes

--Add Crossrefs to TEs

--make network compatible


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
local defToImage = {};
local parentTypes = {};
local countFound = 0;
local countAdded = 0;

for lIndex=0,LangLanguage:GetNumEntries()-1,1 do
  Entry = LangLanguage:GetEntry(lIndex);
  for eIndex=0, Entry:GetNumDescendantsOfElementType(ElementImage:GetID())-1,1 do
    local Image = Entry:GetNthDescendantOfElementType(ElementImage:GetID(),eIndex);
    local fileName = tQuery(Image, "/@FilePathWeb");
    local Parent = Image:GetParent();
    if Parent:GetElement():GetName() == "Sense" then
      for pIndex=0, Parent:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
        local Definition = Parent:GetNthChildOfElementType(ElementDefinition:GetID(),pIndex);
        local def = tQuery(Definition,"/@Definition");
        if defToImage[def] == nil then
          defToImage[def] = {};
        end
        table.insert(defToImage[def],fileName);
        countFound = countFound + 1;
      end
    end
  end
end


for lIndex=0,EngLanguage:GetNumEntries()-1,1 do
  Entry = EngLanguage:GetEntry(lIndex);
  for eIndex=0, Entry:GetNumDescendantsOfElementType(ElementReversalDefinition:GetID())-1,1 do
    local ReversalDefinition = Entry:GetNthDescendantOfElementType(ElementReversalDefinition:GetID(),eIndex);
    local def = tQuery(ReversalDefinition,"/@Definition");
    if defToImage[def] ~= nil then
      local ReversalSense = ReversalDefinition:GetParent();
      if ReversalSense:GetNumChildrenOfElementType(ElementImage:GetID()) == 0 then
        local NodeImage = Doc:AllocateElementByName("Image",true);
        NodeImage:SetAttributeDisplayByString(AttrFilePathWeb,defToImage[def][1]);
        ReversalSense:AddChildOrdered(NodeImage);
        countAdded = countAdded + 1;
        if Entry:HasChanged() == false then
          Entry:SetChanged(true,true);
        end
      end
    end
  end
end


Doc:SetDirty();
Evt_NodeDeleteFromDoc:Trigger(nil, EngLanguage);

return "found: "..countFound.."\nadded: "..countAdded;
