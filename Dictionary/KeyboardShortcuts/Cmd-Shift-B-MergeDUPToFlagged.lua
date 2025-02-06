--$LUA$:--11282023

-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton

--ctrl+shift+b
--for BANK

local Doc=tApp():GetCurrentDoc();
--make network compatible
tRequestLoadAll();

--Include Utility Functions
tLuaLog("Start");

Section=Doc:GetDictionary():GetLanguage(0);
EngLanguage=Doc:GetDictionary():GetLanguage(1);


ElementEntry = Doc:GetDTD():FindElementByName("Entry");
if ElementEntry == nil then return "Entry Element not found"; end

AttrScriptFlag = ElementEntry:FindAttributeByName("ScriptFlag");
if AttrScriptFlag == nil then return "ScriptFlag Attribute not found"; end

AttrCode = ElementEntry:FindAttributeByName("Code");
if AttrCode == nil then return "Code Attribute not found"; end

ElementSense = Doc:GetDTD():FindElementByName("Sense");
if ElementSense == nil then return "Sense Element not found"; end

AttrShortGloss = ElementSense:FindAttributeByName("ShortGloss");
if AttrShortGloss == nil then return "ShortGloss Attribute not found"; end

AttrPartOfSpeech = ElementEntry:FindAttributeByName("PartOfSpeech");
if AttrPartOfSpeech == nil then return "PartOfSpeech Attribute not found"; end

AttrHomonymNumber = ElementEntry:FindAttributeByName("HomonymNumber");
if AttrHomonymNumber == nil then return "HomonymNumber Attribute not found"; end

ElementReferences = Doc:GetDTD():FindElementByName("References");
if ElementReferences == nil then return "References Element not found"; end

ElementSubentry = Doc:GetDTD():FindElementByName("Subentry");
if ElementSubentry == nil then return "Subentry Element not found"; end

AttrSubentryLemma = ElementSubentry:FindAttributeByName("Lemma");
if AttrSubentryLemma == nil then return "Lemma Attribute not found"; end

AttrSubentryPartOfSpeech = ElementSubentry:FindAttributeByName("PartOfSpeech");
if AttrSubentryPartOfSpeech == nil then return "Subentry PartOfSpeech Attribute not found"; end

ElementDefinition = Doc:GetDTD():FindElementByName("Definition");
if ElementDefinition == nil then return "Definition Element not found"; end

AttrDefinition = ElementDefinition:FindAttributeByName("Definition");
if AttrDefinition == nil then return "Definition Attribute not found"; end

ElementTE = Doc:GetDTD():FindElementByName("TE");
if ElementTE == nil then return "TE Element not found"; end

AttrTE = ElementTE:FindAttributeByName("TE");
if AttrTE == nil then return "TE Attribute not found"; end

ElementNotes = Doc:GetDTD():FindElementByName("Notes");
if ElementNotes == nil then return "Notes Element not found"; end

AttrDisplayNote = ElementNotes:FindAttributeByName("DisplayNote");
if AttrDisplayNote == nil then return "DisplayNote Attribute not found"; end

AttrInHouseNote = ElementNotes:FindAttributeByName("InHouseNote");
if AttrInHouseNote == nil then return "InHouseNote Attribute not found"; end

ElementVariantForm = Doc:GetDTD():FindElementByName("VariantForm");
if ElementVariantForm == nil then return "VariantForm Element not found"; end

ElementAudio = Doc:GetDTD():FindElementByName("Audio");
if ElementAudio == nil then return "Audio Element not found"; end

AttrFilePath = ElementAudio:FindAttributeByName("FilePath");
if AttrFilePath == nil then return "FilePath Attribute not found"; end

AttrSpeaker = ElementAudio:FindAttributeByName("Speaker");
if AttrSpeaker == nil then return "Speaker Attribute not found"; end

AttrGender = ElementAudio:FindAttributeByName("Gender");
if AttrGender == nil then return "Gender Attribute not found"; end

ElementAudioBank = Doc:GetDTD():FindElementByName("AudioBank");
if ElementAudioBank == nil then return "AudioBank Element not found"; end

ElementSenseBank = Doc:GetDTD():FindElementByName("SenseBank");
if ElementSenseBank == nil then return "SenseBank Element not found"; end

ElementFormBank = Doc:GetDTD():FindElementByName("FormBank");
if ElementFormBank == nil then return "FormBank Element not found"; end

ElementWordBank = Doc:GetDTD():FindElementByName("WordBank");
if ElementWordBank == nil then return "WordBank Element not found"; end

AttrBankType = ElementWordBank:FindAttributeByName("BankType");
if AttrBankType == nil then return "BankType Attribute not found"; end

ElementSource = Doc:GetDTD():FindElementByName("Source");
if ElementSource == nil then return "Source Element not found"; end

AttrFull = ElementSource:FindAttributeByName("Full");
if AttrFull == nil then return "Full Attribute not found"; end

ElementCorpusDetails = Doc:GetDTD():FindElementByName("CorpusDetails");
--if ElementSource == nil then return "Source Element not found"; end

function recursiveClone(newParent,elementToClone)
  local cindex = 0;
  local rcindex = 0;
  local elementName = elementToClone:GetElement():GetName();
  local NodeNew = Doc:AllocateElementByName(elementName,true);
  if elementName == "References" then
    --tLuaLog("start Reference Cloning in "..elementName);
    local References = tolua.cast(elementToClone, "tcReferences");
    local refDetails = {};
    if References ~= nil and References:GetNumRefEntries() ~= nil then
      refDetails = GetReferencesDetails(References)
      NodeNew = tolua.cast(NodeNew, "tcReferences");
      RestoreRefDetails(NodeNew,refDetails);
    end
  end
  --tLuaLog("start Attr Cloning in "..elementName);
  for cindex=0, elementToClone:GetElement():GetNumAttributes()-1,1 do
    local curAttr = elementToClone:GetElement():GetAttribute(cindex);
    --tLuaLog("SetAttr");
    if curAttr ~= nil then
      NodeNew:SetAttributeDisplayByString(curAttr,elementToClone:GetAttributeDisplayAsString(curAttr));
      --tLuaLog("afterSetAttr "..elementToClone:GetAttributeDisplayAsString(curAttr));
    end
  end
  for rcindex=0,elementToClone:GetNumChildren()-1,1 do
    --tLuaLog("recurseTheClone");
    NodeNew = recursiveClone(NodeNew,elementToClone:GetChild(rcindex));
  end
  --tLuaLog("add new element of type"..elementName);
  local ElementNew = newParent:GetChild(newParent:AddChildOrdered(NodeNew));
  --tLuaLog("return newParent");
  return newParent;
end

function GetReferencesDetails(References)
  local refDetails = {};
  local IndexR = 0;
  if References ~= nil and References:GetNumRefEntries() ~= nil then
    for indexR=0, References:GetNumRefEntries()-1,1 do
      if References:GetRefSense(References:GetRefEntryID(indexR),indexR) ~= nil then
        refDetails[indexR] = {RefEntryID = References:GetRefEntryID(indexR), RefTypeID = References:GetRefType(indexR), RefSenseID = References:GetRefSenseID(References:GetRefEntryID(indexR),indexR)};
      else
        refDetails[indexR] = {RefEntryID = References:GetRefEntryID(indexR), RefTypeID = References:GetRefType(indexR)};
      end
    end
    return refDetails;
  else
    return nil
  end
end

function RestoreRefDetails(References, refDetails)
  if References ~= nil then
    for key,value in pairs(refDetails) do
      if value['RefSenseID'] ~= nil then
        References:AddRefSense(value['RefEntryID'],value['RefSenseID'],value['RefTypeID']);
      else
        References:AddRefEntry(value['RefEntryID'],value['RefTypeID']);
      end
    end
    return 1;
  end
  return 0;
end

function recursiveCloneEntryToSubentry(newParent,elementToClone)
  local cindex = 0;
  local rcindex = 0;
  local elementName = elementToClone:GetElement():GetName();
  local NodeNew = Doc:AllocateElementByName("Subentry",true);
  tLuaLog("start Subentry Attr Cloning");
  local EleSubentry = Doc:GetDTD():FindElementByName("Subentry");
  for cindex=0, elementToClone:GetElement():GetNumAttributes()-1,1 do
    local curEntryAttr = elementToClone:GetElement():GetAttribute(cindex);
    local curAttr = EleSubentry:FindAttributeByName(curEntryAttr:GetName());
    tLuaLog("Subentry SetAttr");
    if curAttr ~= nil then
      NodeNew:SetAttributeDisplayByString(curAttr,elementToClone:GetAttributeDisplayAsString(curEntryAttr));
      tLuaLog("Subentry afterSetAttr");
    end
  end
  for rcindex=0,elementToClone:GetNumChildren()-1,1 do
    tLuaLog("Subentry recurseTheClone");
    NodeNew = recursiveClone(NodeNew,elementToClone:GetChild(rcindex));
  end
  tLuaLog("Subentry add new element");
  local ElementNew = newParent:GetChild(newParent:AddChildOrdered(NodeNew));
  return newParent;
end

function recursiveCompare(element1,element2)
  local cindex = 0;
  local rcindex = 0;
  local elementName1 = element1:GetElement():GetName();
  local elementName2 = element2:GetElement():GetName();
  tLuaLog("4.5");
  if elementName1 ~= elementName2 then
    return false;
  end
  --local NodeNew = Doc:AllocateElementByName(elementName,true);
  for cindex=0, element1:GetElement():GetNumAttributes()-1,1 do
    tLuaLog("5");
    local curAttr1 = element1:GetElement():GetAttribute(cindex);
    local curAttr2 = element2:GetElement():GetAttribute(cindex);
    if curAttr2 == nil or curAttr2 ~= curAttr1 then
      return false;
    end
  end
  if element1:GetNumChildren() ~= element2:GetNumChildren() then
    return false;
  end
  for rcindex=0,element1:GetNumChildren()-1,1 do
    tLuaLog("6");
    local element1New = element1:GetChild(rcindex);
    tLuaLog("7");
    local element2New = element2:GetChild(rcindex);
    tLuaLog(element1New:GetElement():GetName().." and "..element2New:GetElement():GetName());
    if element2 == nil or recursiveCompare(element1New,element2New) == false then
      tLuaLog("6.5");
      return false;
    end
  end
  tLuaLog("7");
  return true;
end

function recursiveDeleteEmptyUpChain(Element)
  tLuaLog("recursiveDeleteEmptyUpChain");
  tLuaLog(Element:GetParent():GetNumChildren().." vs "..Element:GetParent():GetNumChildrenOfElementType(ElementAudio:GetID()));
  if Element:GetParent():GetNumChildren() - Element:GetParent():GetNumChildrenOfElementType(ElementAudio:GetID()) - Element:GetParent():GetNumChildrenOfElementType(ElementVariantForm:GetID()) == 1 then
    recursiveDeleteEmptyUpChain(Element:GetParent());
  else
    local isEntry = false;
    tLuaLog(Element:GetElement():GetName());
    if Element:GetElement():GetName() == "Entry" then
      tLuaLog("Entry is deleted");
      --Element:PreDeleteFromDoc();
      --tFrameWindow():GetSectionWindow(EngLanguage):EntryDelete(Element);
      DeleteEntry(EngLanguage,Element);
      isEntry = true;
    else
      DeleteElement(Element);
    end
    return isEntry;
  end
end

function recursiveGetParentEntry(Element)
  tLuaLog("recursiveGetParentEntry");
  if Element:GetParent() == nil or Element:GetElement():GetName() == "Entry" then
    return tolua.cast(Element, "tcEntry");
  else
    return recursiveGetParentEntry(Element:GetParent());
  end
end

function DeleteEntry(Section, Entry)
  tLuaLog("DeleteElement");
  Entry = tolua.cast(Entry,"tcEntry");
  Entry:PreDeleteFromDoc();
  tFrameWindow():GetSectionWindow(Section):EntryDelete(Entry,true);
end

function DeleteElement(Element)
  tLuaLog("DeleteElement");
  Element:PreDeleteFromDoc();
  Doc:DeleteTreeFromDoc(Element);
end

function CleanTEReferencesForMove(EntryToClean)
  tLuaLog("CleanTEReferencesForMove");
  for eIndex=0,EntryToClean:GetNumDescendantsOfElementType(ElementTE:GetID())-1,1 do
    local TE = EntryToClean:GetNthDescendantOfElementType(ElementTE:GetID(),eIndex);
    if TE:GetNumChildrenOfElementType(ElementReferences:GetID()) > 0 then
      if tRequestModify(EntryToClean,true) then
        local ref = tolua.cast(TE:GetNthChildOfElementType(ElementReferences:GetID(),0),"tcReferences");
        local RefSenseDef = ref:GetRefSense(ref:GetRefEntryID(0),0);
        if RefSenseDef ~= nil then
          local RefSenseDefEntry = recursiveGetParentEntry(RefSenseDef);
          if tRequestModify(RefSenseDefEntry,true) then
            local refEntryDeleted = false;
            if RefSenseDef:GetNumDescendantsOfElementType(ElementReferences:GetID()) == 1 then
              if RefSenseDefEntry:HasChanged() == false then
                RefSenseDefEntry:SetChanged(true,true);
              end
              refEntryDeleted = recursiveDeleteEmptyUpChain(RefSenseDef);
            end
            if refEntryDeleted == false and RefSenseDefEntry ~= nil then
              tLuaLog("changed RefSenseDefEntry")
              if RefSenseDefEntry:HasChanged() == false then
                RefSenseDefEntry:SetChanged(true,true);
              end
            end
          end
        else
          tLuaLog("failed to get refSenseDef")
        end
        --do this no matter what so we can get on with our lives
        DeleteElement(ref);
        if EntryToClean:HasChanged() == false then
          EntryToClean:SetChanged(true,true);
        end
      end
    end
  end
  Evt_NodeDeleteFromDoc:Trigger(nil, EngLanguage);
  Evt_EntryPreDelete:Trigger(nil, EngLanguage);
  Evt_NodeDeleteFromDoc:Trigger(nil, EngLanguage);
end


function dedupTable(inputTable)
  local hash = {};
  local result = {};
  for _, v in ipairs(inputTable) do
    if (not hash[tQuery(v, "/@Full")]) then
        result[#result+1] = v;
        hash[tQuery(v, "/@Full")] = true;
   end
  end
  return result
end

function compareTable(t1, t2)
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v1 ~= v2 then
      return false
    end
  end
  return true
end

function getTableSize(t)
  if t ~= nil and type(t) == "table" then
    local count = 0;
    for _, __ in pairs(t) do
        count = count + 1;
    end
    return count;
  else
    return 0;
  end
end

local lIndex = 0;
local lIndexFix = 0;
local eIndex = 0;
local dIndex = 0;
local rIndex = 0;
local rIndexFix = 0;
local rxIndex = 0;
local xxIndex = 0;
local countCloned = 0;
local countSkipped = 0;
local DestEntry;
local scriptFlag = "";
local SenseMap = {};
for sIndex=0, Doc:GetDictionary():GetNumSections()-1,1 do
  local Section = Doc:GetDictionary():GetLanguage(sIndex);
  for lIndex=0,Section:GetNumEntries()-1,1 do
    Entry = Section:GetEntry(lIndex);
    if tFrameWindow():GetSectionWindow(Section):IsTagged(Entry)  and tRequestModify(Entry,true) then
      if tQuery(Entry,"/@ScriptFlag") ~= "" then
        if scriptFlag == "" then
          scriptFlag = tQuery(Entry,"/@ScriptFlag")
          DestEntry = Entry;
          tFrameWindow():GetSectionWindow(Section):Untag(DestEntry);
        else
          tLuaLog("stopped script due to too many scriptFlags")
          return "there can be only one"
        end
      end
    end
  end
  if DestEntry ~= nil then
    local DestEntryID = DestEntry:GetID();
    for lIndex=0,Section:GetNumEntries()-1,1 do
      Entry = Section:GetEntry(lIndex-lIndexFix);
      local SourceEntryID = Entry:GetID();
      if tFrameWindow():GetSectionWindow(Section):IsTagged(Entry) and tRequestModify(Entry,true) then
        local didntClone = true;
    
        CleanTEReferencesForMove(Entry);
        --sources
        local Sources = {};
        local numSources = DestEntry:GetNumChildrenOfElementType(ElementSource:GetID());
        for sIndex=0,numSources-1,1 do
          local Source = DestEntry:GetNthChildOfElementType(ElementSource:GetID(),sIndex);
          if tQuery(Source, "/@Full") ~= "" then
            table.insert(Sources, Source);
          end
        end
        sizeOriginalSources=getTableSize(dedupTable(Sources));
        --iterate through the descendant subentries


        local numSourcesInSub = Entry:GetNumChildrenOfElementType(ElementSource:GetID());
        for ssIndex=0,numSourcesInSub-1,1 do
          local SourceInSub = Entry:GetNthChildOfElementType(ElementSource:GetID(),ssIndex);
          if tQuery(SourceInSub, "/@Full") ~= "" then
            --add Source elements to table
            table.insert(Sources, SourceInSub);
          end
        end
        newTable = dedupTable(Sources);
        newTableCopy = {};
        for i=1, #newTable do
            newTableCopy[i] = newTable[i];
        end
        table.sort(newTable, function(v1, v2) return tQuery(v1, "/@Full") < tQuery(v2, "/@Full") end);
        sizeNewTable = getTableSize(newTable);
        --if there are new sources in the table from wordbank subentries or alphabetical sort change happened, remove sources already in table, clone to the main entry and mark modified
        if (sizeNewTable ~= sizeOriginalSources) or (sizeNewTable == sizeOriginalSources and compareTable(newTable, newTableCopy) == false) then
          --removing Sources already stored in table
          for endIndex=numSources-1,0,-1 do
            local SourceDel = DestEntry:GetNthChildOfElementType(ElementSource:GetID(),endIndex);
            if tQuery(SourceDel, "/@Full") ~= "" then
              Doc:DeleteTreeFromDoc(SourceDel);
            end
          end
            --iterate through table and recursively clone
          for i=1, #newTable, 1 do
            if newTable[i] ~= nil then
              recursiveClone(DestEntry, newTable[i]);
            end
          end
        end
    --sensebank
        local SenseBank;
        if DestEntry:GetNumChildrenOfElementType(ElementSenseBank:GetID()) == 1 then
          tLuaLog("Finding SenseBank");
          SenseBank = DestEntry:GetNthChildOfElementType(ElementSenseBank:GetID(),0)
        else
          tLuaLog("Making SenseBank");
          local NodeSenseBank = Doc:AllocateElementByName("SenseBank",true);
          SenseBank = DestEntry:GetChild(DestEntry:AddChildOrdered(NodeSenseBank));
        end
        for eIndex = 0,Entry:GetNumChildrenOfElementType(ElementSense:GetID())-1,1 do
          tLuaLog("Cloning into SenseBank");
          recursiveClone(SenseBank,Entry:GetNthChildOfElementType(ElementSense:GetID(),eIndex));
        end
    --audiobank
        local AudioBank;
        if DestEntry:GetNumChildrenOfElementType(ElementAudioBank:GetID()) == 1 then
          tLuaLog("Finding AudioBank");
          AudioBank = DestEntry:GetNthChildOfElementType(ElementAudioBank:GetID(),0)
        else
          tLuaLog("Making AudioBank");
          local NodeAudioBank = Doc:AllocateElementByName("AudioBank",true);
          AudioBank = DestEntry:GetChild(DestEntry:AddChildOrdered(NodeAudioBank));
        end
        for eIndex = 0,Entry:GetNumDescendantsOfElementType(ElementAudio:GetID())-1,1 do
          recursiveClone(AudioBank,Entry:GetNthDescendantOfElementType(ElementAudio:GetID(),eIndex));
        end
      --CorpusDetails
        if ElementCorpusDetails ~= nil then
          local CorpusDetails;
          for eIndex=0, Entry:GetNumChildrenOfElementType(ElementCorpusDetails:GetID())-1,1 do
            recursiveClone(DestEntry,Entry:GetNthDescendantOfElementType(ElementCorpusDetails:GetID(),eIndex));
          end
        end
    --check for wordbank
        local WordBank;
        if DestEntry:GetNumChildrenOfElementType(ElementWordBank:GetID()) == 1 then
          tLuaLog("Finding WordBank");
          WordBank = DestEntry:GetNthDescendantOfElementType(ElementWordBank:GetID(),0)
        else
          tLuaLog("Making WordBank");
          local NodeWB = Doc:AllocateElementByName("WordBank",true);
          NodeWB:SetAttributeDisplayByString(AttrBankType, "DUP");
          WordBank = DestEntry:GetChild(DestEntry:AddChildOrdered(NodeWB));
        end
        if WordBank ~= nil then
          tLuaLog("Cloning Entry");
          recursiveCloneEntryToSubentry(WordBank,Entry);
          for dIndex=0, Entry:GetNumDescendantsOfElementType(ElementSense:GetID())-1,1 do
            SenseMap[Entry:GetNthDescendantOfElementType(ElementSense:GetID(),dIndex):GetID()] = DestEntry:GetNthDescendantOfElementType(ElementSense:GetID(),0):GetID()
          end
          for dIndex=0, Entry:GetNumDescendantsOfElementType(ElementDefinition:GetID())-1,1 do
            SenseMap[Entry:GetNthDescendantOfElementType(ElementDefinition:GetID(),dIndex):GetID()] = DestEntry:GetNthDescendantOfElementType(ElementDefinition:GetID(),0):GetID()
          end
          for xxIndex=0, Doc:GetDictionary():GetNumSections()-1,1 do
            local refSection = Doc:GetDictionary():GetLanguage(xxIndex);
            for lxIndex=0,refSection:GetNumEntries()-1,1 do
              local refEntry = refSection:GetEntry(lxIndex);
              for rxIndex = 0, refEntry:GetNumDescendantsOfElementType(ElementReferences:GetID())-1,1 do
                local refNode = refEntry:GetNthDescendantOfElementType(ElementReferences:GetID(), rxIndex);
                local References = tolua.cast(refNode, "tcReferences");
                rIndexFix = 0;
                for rIndex=0, References:GetNumRefEntries()-1, 1 do
                  local refEntryID = References:GetRefEntryID(rIndex-rIndexFix);
                  if refEntryID == SourceEntryID then
                    local refTypeID = References:GetRefType(rIndex-rIndexFix);
                    if References:GetRefSense(refEntryID,rIndex-rIndexFix) ~= nil then
                      local refSenseID = SenseMap[References:GetRefSenseID(refEntryID,rIndex-rIndexFix)];
                      tLuaLog("AddRef: "..DestEntryID..":"..refSenseID.." - Type: "..refTypeID);
                      References:AddRefSense(DestEntryID,refSenseID,refTypeID);
                    else
                      tLuaLog("AddRef: "..DestEntryID.." - Type: "..refTypeID);
                      References:AddRefEntry(DestEntryID,refTypeID);
                    end
                  end
                end
              end
            end
          end
          didntClone = false;
          countCloned = countCloned + 1;
          --delete the cloned entry
          tFrameWindow():GetSectionWindow(Section):Untag(Entry);
          --Entry:PreDeleteFromDoc();
          --Doc:DeleteTreeFromDoc(Entry);

          Entry:SetAttributeDisplayByString(AttrCode,"MERGED INTO TO "..DestEntry:GetLemmaSign());
          Entry:SetAttributeDisplayByString(AttrScriptFlag,"DELETE ME!");
          Entry:SetLemmaSign(tQuery(Entry,"/@ScriptFlag").."***"..Entry:GetLemmaSign());
          if Entry:HasChanged() == false then
            Entry:SetChanged(true,true);
          end
          --Section:OnLemmaSignChanged(DestEntry);--this was crashing?
          --lIndexFix = lIndexFix + 1;
          --fix duplicate audios
          local AudioFiles = {};
          local eIndexFix = 0;
          local AudioBank = DestEntry:GetNthDescendantOfElementType(ElementAudioBank:GetID(),0)
          if AudioBank ~= nil then
            for eIndex=0,AudioBank:GetNumDescendantsOfElementType(ElementAudio:GetID())-1,1 do
              local Audio = AudioBank:GetNthDescendantOfElementType(ElementAudio:GetID(),eIndex - eIndexFix);
              if AudioFiles[tQuery(Audio,"/@FilePath")] == true then
                if tRequestModify(Entry, true) then
                  Audio:PreDeleteFromDoc();
                  Doc:DeleteTreeFromDoc(Audio);
                  eIndexFix = eIndexFix + 1;
                end
              else
              AudioFiles[tQuery(Audio,"/@FilePath")] = true;
              end
            end
          end
          --fix duplicate senses
          local Definitions = {};
          for eIndex=0,DestEntry:GetNumChildrenOfElementType(ElementSense:GetID())-1,1 do
            local Sense = DestEntry:GetNthChildOfElementType(ElementSense:GetID(),eIndex);
            for sIndex=0,Sense:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
              local Definition = Sense:GetNthChildOfElementType(ElementDefinition:GetID(),sIndex)
              Definitions[tQuery(Definition,"/@Definition")] = true;
              tLuaLog("DestEntry: "..tQuery(Definition,"/@Definition"));
            end
          end
          eIndexFix = 0;
          for eIndex=0,DestEntry:GetNumChildrenOfElementType(ElementSenseBank:GetID())-1,1 do
            local SenseBank = DestEntry:GetNthChildOfElementType(ElementSenseBank:GetID(),eIndex-eIndexFix);
            local numSenses = SenseBank:GetNumChildrenOfElementType(ElementSense:GetID());
            local numSensesDeleted = 0;
            bIndexFix = 0;
            for bIndex=0,SenseBank:GetNumChildrenOfElementType(ElementSense:GetID())-1,1 do
              local Sen = SenseBank:GetNthChildOfElementType(ElementSense:GetID(),bIndex-bIndexFix);
              local numDefs = Sen:GetNumChildrenOfElementType(ElementDefinition:GetID());
              local numDefsDeleted = 0;
              sIndexFix = 0;
              for sIndex=0,Sen:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
                local Def = Sen:GetNthChildOfElementType(ElementDefinition:GetID(),sIndex-sIndexFix);
                tLuaLog("bank: "..tQuery(Def,"/@Definition"));
                if Definitions[tQuery(Def,"/@Definition")] == true then
                  Def:PreDeleteFromDoc();
                  Doc:DeleteTreeFromDoc(Def);
                  sIndexFix = sIndexFix + 1;
                  --countDeletedDefs = countDeletedDefs + 1;
                  numDefsDeleted = numDefsDeleted + 1;

                else
                  Definitions[tQuery(Def,"/@Definition")] = true;
                end
              end
              tLuaLog("defs:"..numDefs.." vs deleted:"..numDefsDeleted);
              if numDefsDeleted == numDefs then
                --delete the sense
                Sen:PreDeleteFromDoc();
                Doc:DeleteTreeFromDoc(Sen);
                bIndexFix = bIndexFix + 1;
                --countDeletedSenses = countDeletedSenses + 1;
                --numSensesDeleted = numSensesDeleted + 1;
              end
            end
            if numSensesDeleted == numSenses then
              --delete the sense

                SenseBank:PreDeleteFromDoc();
                Doc:DeleteTreeFromDoc(SenseBank);
                eIndexFix = eIndexFix + 1;
                --countDeletedSenseBanks = countDeletedSenseBanks + 1;
            end
          end


          if DestEntry:HasChanged() == false then
            DestEntry:SetChanged(true,true);
          end
        end
        if didntClone then
          tFrameWindow():GetSectionWindow(Section):Untag(Entry);
          countSkipped = countSkipped + 1;
        end
        --recursiveCloneEntryToSubentry(Entry,Entry);
      end
    end
    if countSkipped == 0 then
      DestEntry:SetAttributeDisplayByString(AttrScriptFlag,"");
    end
  end
  Evt_LemmasInserted:Trigger(nil, Section);
  Evt_LemmaHomNumChanged:Trigger(nil, Section);
  Evt_EntryPreDelete:Trigger(nil, Section);
  Evt_NodeDeleteFromDoc:Trigger(nil, Section);
end
Doc:SetDirty();
return countCloned.." merged\n"..countSkipped.." skipped";
