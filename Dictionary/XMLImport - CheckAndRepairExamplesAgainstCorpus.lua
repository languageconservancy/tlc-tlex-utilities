-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton


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
dofile(script_path().lang..'Common.lua');
dofile(script_path().global..'Common.lua');

local lIndex=0;
local eIndex=0;
local count=0;
local countNoMatch = 0;
local countDiffExPhr = 0;
local countDiffTrans = 0;
local countINFNoMatch = 0;
local countDiffINF = 0;
local countDiffINFTrans = 0;
local resultText = "";

for sIndex=0, Doc:GetDictionary():GetNumSections()-1,1 do
  local Section = Doc:GetDictionary():GetLanguage(sIndex);
  for lIndex=0,Section:GetNumEntries()-1,1 do
    Entry = Section:GetEntry(lIndex);
    if tFrameWindow():GetSectionWindow(Section):IsTagged(Entry) then
      for eIndex=0,Entry:GetNumDescendantsOfElementType(ElementExPhrase:GetID())-1,1 do
        local ExPhrase = Entry:GetNthDescendantOfElementType(ElementExPhrase:GetID(),eIndex);
        if ExPhrase:GetNumChildrenOfElementType(ElementReferences:GetID()) == 0 then
          --tLuaLog(tQuery(ExPhrase,"/@ExPhrase"));
          --TLCLog("EXPHRASE: "..tQuery(ExPhrase,"/@ExPhrase"));
          countNoMatch = countNoMatch + 1;
          local NewExampleEntry = AddEntry(ExamplesSection,tQuery(ExPhrase,"/@ExPhrase"));
          NewExampleEntry:SetAttributeDisplayByString(AttrPartOfSpeech,"PHR");
          --AddEntryReference(ExPhrase,NewCorpusEntry:GetID(),1);
          local NodeSense = Doc:AllocateElementByName("Sense", true);
          NewExampleEntry:AddChildOrdered(NodeSense);
          local NodeDefinition = Doc:AllocateElementByName("Definition", true);
          NodeSense:AddChildOrdered(NodeDefinition);
          NodeDefinition:SetAttributeDisplayByString(AttrDefinition, tQuery(ExPhrase,"/@Translation"));

          --move audio
          local NodeAudioBank = Doc:AllocateElementByName("AudioBank", true);
          local exIndex = 0;
          for exIndex=0,ExPhrase:GetNumChildrenOfElementType(ElementAudio:GetID())-1,1 do
            recursiveClone(NodeAudioBank,ExPhrase:GetNthChildOfElementType(ElementAudio:GetID(),exIndex));
          end
          AudioBank = NewExampleEntry:GetChild(NewExampleEntry:AddChildOrdered(NodeAudioBank));

          --copy sources
          local eeIndex=0;
          for eeIndex=0,Entry:GetNumChildrenOfElementType(ElementSource:GetID())-1,1 do
            recursiveClone(NewExampleEntry,Entry:GetNthChildOfElementType(ElementSource:GetID(),eeIndex));
          end

          AddCode(NewExampleEntry,"NEWEXAMPLE");
          NewExampleEntry:SetNew(true,true);
          if NewExampleEntry:HasChanged() == false then
            NewExampleEntry:SetChanged(true,true);
          end
          AddEntryReference(ExPhrase,NewExampleEntry:GetID(),1);

          if Entry:HasChanged() == false then
            Entry:SetChanged(true,true);
          end
        end
      end

      ---Examples
      for eIndex=0,Entry:GetNumDescendantsOfElementType(ElementExample:GetID())-1,1 do
        local Example = Entry:GetNthDescendantOfElementType(ElementExample:GetID(),eIndex);
        if Example:GetNumChildrenOfElementType(ElementReferences:GetID()) == 0 then
          --tLuaLog(tQuery(Example,"/@Example"));
          --TLCLog("Example: "..tQuery(Example,"/@Example"));
          countNoMatch = countNoMatch + 1;
          local NewExampleEntry = AddEntry(ExamplesSection,tQuery(Example,"/@Example"));
          NewExampleEntry:SetAttributeDisplayByString(AttrPartOfSpeech,"PHR");
          --AddEntryReference(Example,NewCorpusEntry:GetID(),1);
          local NodeSense = Doc:AllocateElementByName("Sense", true);
          NewExampleEntry:AddChildOrdered(NodeSense);
          local NodeDefinition = Doc:AllocateElementByName("Definition", true);
          NodeSense:AddChildOrdered(NodeDefinition);
          NodeDefinition:SetAttributeDisplayByString(AttrDefinition, tQuery(Example,"/@Translation"));

          --move audio
          local NodeAudioBank = Doc:AllocateElementByName("AudioBank", true);
          local exIndex = 0;
          for exIndex=0,Example:GetNumChildrenOfElementType(ElementAudio:GetID())-1,1 do
            recursiveClone(NodeAudioBank,Example:GetNthChildOfElementType(ElementAudio:GetID(),exIndex));
          end
          AudioBank = NewExampleEntry:GetChild(NewExampleEntry:AddChildOrdered(NodeAudioBank));

          --copy sources
          local eeIndex=0;
          for eeIndex=0,Entry:GetNumChildrenOfElementType(ElementSource:GetID())-1,1 do
            recursiveClone(NewExampleEntry,Entry:GetNthChildOfElementType(ElementSource:GetID(),eeIndex));
          end

          AddCode(NewExampleEntry,"NEWEXAMPLE");
          NewExampleEntry:SetNew(true,true);
          if NewExampleEntry:HasChanged() == false then
            NewExampleEntry:SetChanged(true,true);
          end
          AddEntryReference(Example,NewExampleEntry:GetID(),1);

          if Entry:HasChanged() == false then
            Entry:SetChanged(true,true);
          end
        end
      end
    end
  end
end
Doc:SetDirty();
return countINFNoMatch.." Inflections not on corpus side\n"..countDiffINF.." Inflections are different!\n"..countDiffINFTrans.." Translations are different!\n\n"..countNoMatch.." Exphrases not on corpus side\n"..countDiffExPhr.." Exphrases are different!\n"..countDiffTrans.." Translations are different!";
