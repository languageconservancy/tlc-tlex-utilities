--$LUA$:--09282023

-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton

--ctrl+shift+e
--for EXAMPLE

local Doc=tApp():GetCurrentDoc();
--make network compatible
tRequestLoadAll();

--Include Utility Functions
tLuaLog("Start");

LangLanguage=Doc:GetDictionary():GetLanguage(0);
EngLanguage=Doc:GetDictionary():GetLanguage(0);

ElementEntry = Doc:GetDTD():FindElementByName("Entry");
if ElementEntry == nil then return "Entry Element not found"; end

ElementTE = Doc:GetDTD():FindElementByName("TE");
if ElementTE == nil then return "TE Element not found"; end

ElementReferences = Doc:GetDTD():FindElementByName("References");
if ElementReferences == nil then return "References Element not found"; end

ElementSense = Doc:GetDTD():FindElementByName("Sense");
if ElementSense == nil then return "Sense Element not found"; end

ElementDefinition = Doc:GetDTD():FindElementByName("Definition");
if ElementDefinition == nil then return "Definition Element not found"; end

ElementAudio = Doc:GetDTD():FindElementByName("Audio");
if ElementAudio == nil then return "Audio Element not found"; end

ElementVariantForm = Doc:GetDTD():FindElementByName("VariantForm");
if ElementVariantForm == nil then return "VariantForm Element not found"; end

AttrScriptFlag = ElementEntry:FindAttributeByName("ScriptFlag");
if AttrScriptFlag == nil then return "ScriptFlag Attribute not found"; end

AttrCode = ElementEntry:FindAttributeByName("Code");
if AttrCode == nil then return "Code Attribute not found"; end

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


local sIndex = 0;
local lIndex = 0;
local lIndexFix = 0;
local eIndex = 0;
local dIndex = 0;
local cIndex = 0;
local rIndex = 0;
local rIndexFix = 0;
local rxIndex = 0;
local xxIndex = 0;
local countCloned = 0;
local countSkipped = 0;
local DestEntry;
local DestLanguage;
local SenseMap = {};
for sIndex=0, Doc:GetDictionary():GetNumSections()-1,1 do
  local Section = Doc:GetDictionary():GetLanguage(sIndex);
  for lIndex=0,Section:GetNumEntries()-1,1 do
    local Entry = Section:GetEntry(lIndex - lIndexFix);
    local SourceEntryID = Entry:GetID();
    if tFrameWindow():GetSectionWindow(Section):IsTagged(Entry) then
      if tRequestModify(Entry, true) then
        if tQuery(Entry,"/@ScriptFlag") ~= "" then

          --local scriptFlags = SplitFirst(tQuery(Entry,"/@ScriptFlag"),":");
          DestLanguage=Doc:GetDictionary():GetLanguage(math.floor(tQuery(Entry,"/@ScriptFlag"))-1);
          if DestLanguage ~= nil then
            local NodeDestEntry = Doc:AllocateElementByID(NODE_ENTRY,true);
            DestEntry = tolua.cast(NodeDestEntry, "tcEntry");
            DestEntry:SetLemmaSign(Entry:GetLemmaSign());
            DestEntry = DestLanguage:GetEntry(DestLanguage:InsertEntry(DestEntry));
            --now clone entry attributes
            if DestEntry~=nil then
              DestEntry:SetNew(true,true);
              DestEntry:SetChanged(true,true);
              local DestEntryID = DestEntry:GetID();
              tLuaLog("DestID: "..DestEntryID);
              if tRequestModify(DestEntry, true) then
                for cIndex=0, Entry:GetElement():GetNumAttributes()-1,1 do
                  local curAttr = Entry:GetElement():GetAttribute(cIndex);
                  tLuaLog("SetAttr");
                  if curAttr ~= nil then
                    DestEntry:SetAttributeDisplayByString(curAttr,Entry:GetAttributeDisplayAsString(curAttr));
                  end
                end
                CleanTEReferencesForMove(Entry);
                for cIndex=0, Entry:GetNumChildren()-1,1 do
                  recursiveClone(DestEntry,Entry:GetChild(cIndex));
                end
                for dIndex=0, DestEntry:GetNumDescendantsOfElementType(ElementSense:GetID())-1,1 do
                  SenseMap[Entry:GetNthDescendantOfElementType(ElementSense:GetID(),dIndex):GetID()] = DestEntry:GetNthDescendantOfElementType(ElementSense:GetID(),dIndex):GetID()
                end
                for dIndex=0, DestEntry:GetNumDescendantsOfElementType(ElementDefinition:GetID())-1,1 do
                  SenseMap[Entry:GetNthDescendantOfElementType(ElementDefinition:GetID(),dIndex):GetID()] = DestEntry:GetNthDescendantOfElementType(ElementDefinition:GetID(),dIndex):GetID()
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
                          local refSense = References:GetRefSense(refEntryID,rIndex-rIndexFix);
                          if refSense ~= nil then
                            tLuaLog(References:GetRefEntry(rIndex-rIndexFix):GetLemmaSign());
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
                --delete the cloned entry
                tLuaLog("Deleting Cloned Entry");
                tFrameWindow():GetSectionWindow(LangLanguage):Untag(Entry);
                --Entry:PreDeleteFromDoc();
                --Doc:DeleteTreeFromDoc(Entry);
                Entry:SetAttributeDisplayByString(AttrCode,"MOVED TO "..tQuery(Entry,"/@ScriptFlag"));
                Entry:SetAttributeDisplayByString(AttrScriptFlag,"DELETE ME!");
                Entry:SetLemmaSign(tQuery(Entry,"/@ScriptFlag").."***"..Entry:GetLemmaSign());
                --Section:PreviewRefreshEntry(Entry);
                --LangLanguage:OnLemmaSignChanged(DestEntry);--this was crashing?
                --lIndexFix = lIndexFix + 1;
                countCloned = countCloned + 1;
                DestEntry:SetAttributeDisplayByString(AttrScriptFlag,"");
                Evt_LemmasInserted:Trigger(nil, DestLanguage);

              else
                tFrameWindow():GetSectionWindow(Section):Untag(Entry);
              end
            else
              tFrameWindow():GetSectionWindow(Section):Untag(Entry);
            end
          end
        else
          tFrameWindow():GetSectionWindow(Section):Untag(Entry);
        end
      else
        tFrameWindow():GetSectionWindow(Section):Untag(Entry);
      end
    end
  end
  --Section:RefreshPreview();
  --Section:RefreshWindow();
  --Section:RebuildAttributes();
  --Section:RefreshEverything();
end
Doc:SetDirty();
return countCloned.." moved";
