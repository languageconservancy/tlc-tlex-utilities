--$LUA$:--02132024

-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton

--ctrl+shift+m
--for MORPHOLOGY


local Doc=tApp():GetCurrentDoc();

tRequestLoadAll();

local ElementMorphology = Doc:GetDTD():FindElementByName("Morphology");
if ElementMorphology == nil then return "Morphology Element not found"; end
local ElementEntry = Doc:GetDTD():FindElementByName("Entry");
if ElementEntry == nil then return "Entry Element not found"; end
local ElementSense = Doc:GetDTD():FindElementByName("Sense");
if ElementSense == nil then return "Sense Element not found"; end
local AttrMorphology = ElementEntry:FindAttributeByName("Morphology");
if AttrMorphology == nil then return "Morphology Attribute not found"; end
local ElementReferences = Doc:GetDTD():FindElementByName("References");
if ElementReferences == nil then return "References Element not found"; end
local ElementMorpheme = Doc:GetDTD():FindElementByName("Morpheme");
if ElementMorpheme == nil then return "Morpheme Element not found"; end
local AttrMorpheme = ElementMorpheme:FindAttributeByName("Morpheme");
if AttrMorpheme == nil then return "Morpheme Attribute not found"; end
local AttrGloss = ElementMorpheme:FindAttributeByName("Gloss");
if AttrGloss == nil then return "Gloss Attribute not found"; end
local AttrGrammarLabel = ElementMorpheme:FindAttributeByName("GrammarLabel");
if AttrGrammarLabel == nil then
  AttrGrammarLabel = ElementMorpheme:FindAttributeByName("GrammaticalLabel");
  if AttrGrammarLabel == nil then
    return "GrammarLabel Attribute not found";
  end
end
local ElementDefinition = Doc:GetDTD():FindElementByName("Definition");
if ElementDefinition == nil then return "Definition Element not found"; end

local eIndex=0;
local mIndex=0;
local rIndex=0;
local morphologyString = "";

if tFrameWindow():GetSectionWindow(gCurrentEntry:GetParent()):IsTagged(gCurrentEntry) then
  if tRequestModify(gCurrentEntry, true) then
    if gCurrentEntry:GetNumChildrenOfElementType(ElementMorphology:GetID()) == 0 then
      --create a morphology for each word
      local lemma = gCurrentEntry:GetLemmaSign();
      local _, c = lemma:gsub(" ","");
      tLuaLog(c.." words found");
      for eIndex = 0, c, 1 do
        local NodeMorphology = Doc:AllocateElementByName("Morphology",true);
        gCurrentEntry:AddChildOrdered(NodeMorphology);
        tLuaLog("adding morphology")
      end
    else
      for eIndex=0, gCurrentEntry:GetNumChildrenOfElementType(ElementMorphology:GetID())-1,1 do
        local Morphology = gCurrentEntry:GetNthChildOfElementType(ElementMorphology:GetID(),eIndex);

        if morphologyString ~= "" and Morphology:GetNumChildren() > 0  then
          morphologyString = morphologyString.." +";--between words
        end
        
        for mIndex=0, Morphology:GetNumChildren()-1,1 do
          if morphologyString ~= "" then
            morphologyString = morphologyString.." ";
          end
          if Morphology:GetChild(mIndex):GetElement():GetName() == "Morpheme" then
            local Morpheme = Morphology:GetChild(mIndex);
            if Morpheme:GetAttributeDisplayAsString(AttrMorpheme) ~= "" then
              morphologyString = morphologyString.." "..Morpheme:GetAttributeDisplayAsString(AttrMorpheme);
            end
            if Morpheme:GetAttributeDisplayAsString(AttrGloss) ~= "" then
              morphologyString = morphologyString.." ‘"..Morpheme:GetAttributeDisplayAsString(AttrGloss).."’";
            else
              if Morpheme:GetAttributeDisplayAsString(AttrGrammarLabel) ~= "" then
                morphologyString = morphologyString.." "..Morpheme:GetAttributeDisplayAsString(AttrGrammarLabel);
              end
            end
          end
          if Morphology:GetChild(mIndex):GetElement():GetName() == "References" then
            local References = tolua.cast(Morphology:GetChild(mIndex), "tcReferences");
            for rIndex=0, References:GetNumRefEntries()-1,1 do
              local refEntry = References:GetRefEntry(rIndex);
              --morphologyString = morphologyString.." "..refEntry:GetLemmaSign();
              local currentRefID = References:GetRefEntryID(rIndex);
              local refSense = References:GetRefSense(currentRefID, rIndex)
              if refSense == nil and refEntry:GetNumChildrenOfElementType(ElementSense:GetID()) > 0 then
                refSense = refEntry:GetNthChildOfElementType(ElementSense:GetID(),0);
              end
              if refSense ~= nil then
                --check type of refSense
                --if sense
                if refSense:GetElement():GetName() == "Sense" then
                  if tQuery(refSense, "/@ShortGloss") ~= nil and tQuery(refSense, "/@ShortGloss") ~= "" then
                    morphologyString = morphologyString.." "..refEntry:GetLemmaSign().." ‘"..tQuery(refSense, "/@ShortGloss").."’";
                  else
                    if tQuery(refEntry, "/@StemHandle") ~= nil and tQuery(refEntry, "/@StemHandle") ~= "" then
                      morphologyString = morphologyString.." "..refEntry:GetLemmaSign().." ‘"..tQuery(refEntry, "/@StemHandle").."’";
                    else
                      local refDef = refSense:GetNthChildOfElementType(ElementDefinition:GetID(),0);
                      if refDef ~= nil then
                        morphologyString = morphologyString.." "..refEntry:GetLemmaSign().." ‘"..tQuery(refDef,"/@Definition").."’";
                      end
                    end
                  end
                end
                if refSense:GetElement():GetName() == "InflectedForm" then
                  if tQuery(refSense, "/@WordForm") ~= nil and tQuery(refSense, "/@WordForm") ~= "" then
                    morphologyString = morphologyString.." "..tQuery(refSense, "/@WordForm").." ‘"..tQuery(refSense, "/@Translation").."’";
                  end
                end
                if refSense:GetElement():GetName() == "InflectedForms" then
                  if tQuery(refSense,"/@StemForm") ~= nil and tQuery(refSense,"/@StemForm") ~= "" then
                    morphologyString = morphologyString.." "..tQuery(refSense, "/@StemForm").." ‘"..tQuery(refSense, "/@BaseMeaning").."’";
                  else
                    refSense = refSense:GetChild(0);
                    if tQuery(refSense, "/@WordForm") ~= nil and tQuery(refSense, "/@WordForm") ~= "" then
                      morphologyString = morphologyString.." "..tQuery(refSense, "/@WordForm").." ‘"..tQuery(refSense, "/@Translation").."’";
                    end
                  end
                end
                --if inflected form
                --if inflected froms
              else
                if tQuery(refEntry, "/@StemHandle") ~= nil and tQuery(refEntry, "/@StemHandle") ~= "" then
                  morphologyString = morphologyString.." "..refEntry:GetLemmaSign().." ‘"..tQuery(refEntry, "/@StemHandle").."’";
                end
              end
              
            end
          end
        end
      end
      gCurrentEntry:SetAttributeDisplayByString(AttrMorphology,morphologyString);
      if gCurrentEntry:HasChanged() == false then
        gCurrentEntry:SetChanged(true,true);
      end
    end

    local ElementLemmas = Doc:GetDTD():FindElementByName("Lemmas");
    if ElementLemmas == nil then
      tLuaLog("Lemmas Element not found");
    else
      if gCurrentEntry:GetNumChildrenOfElementType(ElementLemmas:GetID()) == 0 then
        --create a morphology for each word
        local lemma = gCurrentEntry:GetLemmaSign();
        local _, c = lemma:gsub(" ","");
        tLuaLog(c.." words found");
        for eIndex = 0, c, 1 do
          local NodeLemmas = Doc:AllocateElementByName("Lemmas",true);
          gCurrentEntry:AddChildOrdered(NodeLemmas);
          tLuaLog("adding morphology")
        end
      else
        for eIndex=0, gCurrentEntry:GetNumChildrenOfElementType(ElementLemmas:GetID())-1,1 do
          local Lemmas = gCurrentEntry:GetNthChildOfElementType(ElementLemmas:GetID(),eIndex);
          if morphologyString ~= "" and Lemmas:GetNumChildren() > 0 then
            morphologyString = morphologyString.." +";--between words
          end
          
          for mIndex=0, Lemmas:GetNumChildren()-1,1 do
            if morphologyString ~= "" then
              morphologyString = morphologyString..'] ---- [';
            end
            if Lemmas:GetChild(mIndex):GetElement():GetName() == "References" then
              local References = tolua.cast(Lemmas:GetChild(mIndex), "tcReferences");
              for rIndex=0, References:GetNumRefEntries()-1,1 do
                local refEntry = References:GetRefEntry(rIndex);
                --morphologyString = morphologyString.." "..refEntry:GetLemmaSign();
                local currentRefID = References:GetRefEntryID(rIndex);
                local refSense = References:GetRefSense(currentRefID, rIndex)
                if refSense == nil and refEntry:GetNumChildrenOfElementType(ElementSense:GetID()) > 0 then
                  refSense = refEntry:GetNthChildOfElementType(ElementSense:GetID(),0);
                end
                if refSense ~= nil then
                  --check type of refSense
                  --if sense
                  if refSense:GetElement():GetName() == "Sense" then
                    if tQuery(refSense, "/@ShortGloss") ~= nil and tQuery(refSense, "/@ShortGloss") ~= "" then
                      morphologyString = morphologyString.." "..refEntry:GetLemmaSign().." ‘"..tQuery(refSense, "/@ShortGloss").."’";
                    else
                      if tQuery(refEntry, "/@StemHandle") ~= nil and tQuery(refEntry, "/@StemHandle") ~= "" then
                        morphologyString = morphologyString.." "..refEntry:GetLemmaSign().." ‘"..tQuery(refEntry, "/@StemHandle").."’";
                      else
                        local refDef = refSense:GetNthChildOfElementType(ElementDefinition:GetID(),0);
                        if refDef ~= nil then
                          morphologyString = morphologyString.." "..refEntry:GetLemmaSign().." ‘"..tQuery(refDef,"/@Definition").."’";
                        end
                      end
                    end
                  end
                  if refSense:GetElement():GetName() == "InflectedForm" then
                    if tQuery(refSense, "/@WordForm") ~= nil and tQuery(refSense, "/@WordForm") ~= "" then
                      morphologyString = morphologyString.." "..tQuery(refSense, "/@WordForm").." ‘"..tQuery(refSense, "/@Translation");
                    end
                  end
                  if refSense:GetElement():GetName() == "InflectedForms" then
                    if tQuery(refSense,"/@StemForm") ~= nil and tQuery(refSense,"/@StemForm") ~= "" then
                      morphologyString = morphologyString.." "..tQuery(refSense, "/@StemForm").." ‘"..tQuery(refSense, "/@BaseMeaning");
                    else
                      refSense = refSense:GetChild(0);
                      if tQuery(refSense, "/@WordForm") ~= nil and tQuery(refSense, "/@WordForm") ~= "" then
                        morphologyString = morphologyString.." "..tQuery(refSense, "/@WordForm").." ‘"..tQuery(refSense, "/@Translation");
                      end
                    end
                  end
                  --if inflected form
                  --if inflected froms
                else
                  if tQuery(refEntry, "/@StemHandle") ~= nil and tQuery(refEntry, "/@StemHandle") ~= "" then
                    morphologyString = morphologyString.." "..refEntry:GetLemmaSign().." ‘"..tQuery(refEntry, "/@StemHandle").."’";
                  end
                end
                
              end
            end
          end
        end
        gCurrentEntry:SetAttributeDisplayByString(AttrMorphology,morphologyString);
        if gCurrentEntry:HasChanged() == false then
          gCurrentEntry:SetChanged(true,true);
        end
      end
    end
    Doc:SetDirty();
  else
    tLuaLog("entry cannot be checked out");
    return "Entry cannot be checked out";
  end
end
return morphologyString;
