-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton

tLuaLog("Loaded Global Common");

function testGlobalCommon()
  return "testGlobalCommon() Success"
end

testGlobalCommonString = "testGlobalCommonString Success";

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

function Trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function Split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("%s*(.-)"..delimiter) do
        table.insert(result, match);
    end
    if getTableSize(result) == 0 then
      table.insert(result, s);
    end
    return result;
end

function SplitFirst(s, delimiter)
    result = {};
    local count = 0;
    for match in (s..delimiter):gmatch("%s*(.-)"..delimiter) do
      count = count + 1;
      if count <= 2 then
        table.insert(result, match);
      else
        result[2] = result[2]..delimiter..match;
      end
    end
    if getTableSize(result) == 0 then
      result[1] = s;
    end
    return result;
end

function SaveTableToFile(data, fileName)
  local filePath = string.match(debug.getinfo(2, "S").source:sub(2),"(.*[/\\])");
  if getTableSize(data) > 0 then
    local file = io.open(filePath..fileName..".lua", "w+");
    file:write( fileName.."="..string.sub(RecursiveTableToString(data),1,-2));
    file:close();
  end
end

function OpenTableFile(fileName)
  if FileExists(fileName) == false then
    CreateTableFile(fileName);
  end
  local filePath = string.match(debug.getinfo(2, "S").source:sub(2),"(.*[/\\])");
  dofile(filePath..fileName..".lua");
  return "success";
end

function CreateTableFile(fileName)
  local filePath = string.match(debug.getinfo(2, "S").source:sub(2),"(.*[/\\])");
  local file = io.open(filePath..fileName..".lua", "w");
  file:write( fileName.."= {}");
  file:close();
end

function FileExists(fileName)
   local filePath = string.match(debug.getinfo(2, "S").source:sub(2),"(.*[/\\])");
   local f=io.open(filePath..fileName..".lua","r")
   if f~=nil then io.close(f) return true else return false end
end

function CleanTEReferencesForDelete(EntryToClean)
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

function DeleteEntryReferenceCreatedElements(Entry)
  tLuaLog("DeleteEntryReferenceCreatedElements");
  tLuaLog(Entry:GetLemmaSign());
  local rIndex, lxIndex, xxIndex, rxIndex; --indexes
  local deletedCrossRefed = false;
  for xxIndex=0, Doc:GetDictionary():GetNumSections()-1,1 do
      local refSection = Doc:GetDictionary():GetLanguage(xxIndex);
      for lxIndex=0,refSection:GetNumEntries()-1,1 do
          local refEntry = refSection:GetEntry(lxIndex);
          local rxIndexFix = 0;
          for rxIndex = 0, refEntry:GetNumDescendantsOfElementType(ElementReferences:GetID())-1,1 do
              local refNode = refEntry:GetNthDescendantOfElementType(ElementReferences:GetID(), rxIndex-rxIndexFix);
              local References = tolua.cast(refNode, "tcReferences");
              rIndexFix = 0;
              for rIndex=0, References:GetNumRefEntries()-1, 1 do
                  local refEntryID = References:GetRefEntryID(rIndex-rIndexFix);
                  if refEntryID == Entry:GetID() then
                    --has ref so may be populating the parent  
                    local Parent = References:GetParent();
                    if tRegMatch(Parent:GetElement():GetName(),"InflectedForm|DerivedForm|VariantForm|Example|ExPhrase|CrossRef|Redirect") then
                      DeleteElement(Parent);
                      rxIndexFix = rxIndexFix + 1;
                      if refEntry:HasChanged() == false then
                        refEntry:SetChanged(true,true);
                      end
                      deletedCrossRefed = true;
                    end
                  end
              end
          end
      end
      if deletedCrossRefed then
        Evt_NodeDeleteFromDoc:Trigger(nil, refSection);
      end
    end
  return deletedCrossRefed;
end

function CheckHasBeenReferenced(checkEntry)
  local rIndex, lxIndex, xxIndex, rxIndex; --indexes
  local hasBeenCrossRefed = false;
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
                  if refEntryID == checkEntry:GetID() then
                      hasBeenCrossRefed = true;
                      break;
                  end
                  if hasBeenCrossRefed == true then break; end
              end
              if hasBeenCrossRefed == true then break; end
          end
          if hasBeenCrossRefed == true then break; end
      end
      if hasBeenCrossRefed == true then break; end
  end
  return hasBeenCrossRefed;
end

function RecursiveTableToString(data)
  local stringStart = "";
  local stringEnd = "";
  if type(data) == "table" then
    stringStart = stringStart.."\n{\n";
    stringEnd = "\n}\n"..stringEnd;
    for key,value in pairs(data) do
      stringStart = stringStart.."[\'"..string.gsub(key,"\'","\\\'").."\']".."="..RecursiveTableToString(value);
    end
    stringStart = stringStart:sub(1,-2);--strip last comma
  else
    stringStart = "\""..data.."\"";
  end
  return stringStart..stringEnd..",";
end

function ParseCSVLine (line,sep)
   local res = {}
   local pos = 1
   sep = sep or ','
   while true do
      local c = string.sub(line,pos,pos)
      if (c == "") then break end
      local posn = pos
      local ctest = string.sub(line,pos,pos)
      --trace(ctest)
      while ctest == ' ' do
         -- handle space(s) at the start of the line (with quoted values)
         posn = posn + 1
         ctest = string.sub(line,posn,posn)
         if ctest == '"' then
            pos = posn
            c = ctest
         end
      end
      if (c == '"') then
         -- quoted value (ignore separator within)
         local txt = ""
         repeat
            local startp,endp = string.find(line,'^%b""',pos)
            txt = txt..string.sub(line,startp+1,endp-1)
            pos = endp + 1
            c = string.sub(line,pos,pos)
            if (c == '"') then
               txt = txt..'"'
               -- check first char AFTER quoted string, if it is another
               -- quoted string without separator, then append it
               -- this is the way to "escape" the quote char in a quote. example:
               --   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
            elseif c == ' ' then
               -- handle space(s) before the delimiter (with quoted values)
               while c == ' ' do
                  pos = pos + 1
                  c = string.sub(line,pos,pos)
               end
            end
         until (c ~= '"')
         table.insert(res,txt)
         --trace(c,pos,i)
         if not (c == sep or c == "") then
            error("ERROR: Invalid CSV field - near character "..pos.." in this line of the CSV file: \n"..line, 3)
         end
         pos = pos + 1
         posn = pos
         ctest = string.sub(line,pos,pos)
         --trace(ctest)
         while ctest == ' ' do
            -- handle space(s) after the delimiter (with quoted values)
            posn = posn + 1
            ctest = string.sub(line,posn,posn)
            if ctest == '"' then
               pos = posn
               c = ctest
            end
         end
      else
         -- no quotes used, just look for the first separator
         local startp,endp = string.find(line,sep,pos)
         if (startp) then
            table.insert(res,string.sub(line,pos,startp-1))
            pos = endp + 1
         else
            -- no separator found -> use rest of string and terminate
            table.insert(res,string.sub(line,pos))
            break
         end
      end
   end
   return res
end

function starts_with(str, start)
   return str:sub(1, #start) == start
end

function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

function recursiveGetParentEntry(Element)
  tLuaLog("recursiveGetParentEntry");
  if Element:GetParent() == nil or Element:GetElement():GetName() == "Entry" then
    return tolua.cast(Element, "tcEntry");
  else
    return recursiveGetParentEntry(Element:GetParent());
  end
end

function TableContains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

function GetReferencedEntry(ref)
  local References = tolua.cast(ref, "tcReferences");
  for rIndex=0, References:GetNumRefEntries()-1,1 do
    local refEntry = References:GetRefEntry(rIndex);
    if refEntry ~= nil then
      return refEntry;
    end
  end
  return nil;
end

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

function recursiveMove(newParent, elementToMove)
  recursiveClone(newParent, elementToMove);
  elementToMove:PreDeleteFromDoc();
  Doc:DeleteTreeFromDoc(elementToMove);
end

function DeleteElement(Element)
  --tLuaLog("DeleteElement");
  Element:PreDeleteFromDoc();
  Doc:DeleteTreeFromDoc(Element);
end

function DeleteAllChildrenOfElementType(Parent,ElementID)
  --tLuaLog("DeleteAllChildrenOfElementType");
  local pIndex = 0;
  local pIndexFix = 0;
  for pIndex = 0, Parent:GetNumChildrenOfElementType(ElementID)-1,1 do
    local Child = Parent:GetNthChildOfElementType(ElementID,pIndex-pIndexFix);
    DeleteElement(Child);
    pIndexFix = pIndexFix + 1;
  end
  return pIndexFix;
end

function DeleteEntry(Section, Entry)
  tLuaLog("DeleteElement");
  Entry = tolua.cast(Entry,"tcEntry");
  Entry:PreDeleteFromDoc();
  tFrameWindow():GetSectionWindow(Section):EntryDelete(Entry,true);
end

function recursiveDeleteEmptyUpChain(Element)
  tLuaLog("recursiveDeleteEmptyUpChain");
  tLuaLog(Element:GetParent():GetNumChildren().." vs "..Element:GetParent():GetNumChildrenOfElementType(ElementAudio:GetID()));
  if Element:GetParent():GetNumChildren() - Element:GetParent():GetNumChildrenOfElementType(ElementAudio:GetID()) - Element:GetParent():GetNumChildrenOfElementType(ElementInflectedForm:GetID()) - Element:GetParent():GetNumChildrenOfElementType(ElementVariantForm:GetID()) == 1 then
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

function recursiveObjectCreator(elementToObject)
  local obj = {};
  local cindex = 0;
  local rcindex = 0;
  local elementName = elementToObject:GetElement():GetName();
  local NodeNew = Doc:AllocateElementByName(elementName,true);
  for cindex=0, elementToObject:GetElement():GetNumAttributes()-1,1 do
    local curAttr = elementToObject:GetElement():GetAttribute(cindex);
    if curAttr ~= nil then
      table.insert(obj,elementToObject:GetAttributeDisplayAsString(curAttr));
    else
      table.insert(obj,"");
    end
  end
  for rcindex=0,elementToObject:GetNumChildren()-1,1 do
    table.insert(obj,recursiveObjectCreator(elementToObject:GetChild(rcindex)));
  end
  return obj;
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


function TLCLog(message)
  if message == nil then
    message = "";
  end
  local LogPath = string.match(debug.getinfo(2, "S").source:sub(2),"(.*[/\\])")
  local file = io.open(LogPath.."log.txt", "a+");
  --tLuaLog("writing message");
  file:write( os.date()..": "..message.."\n" );
  file:close();
end

function AddEntryReference(TargetElement,refID,refTypeID)
  if TargetElement ~= nil then
    local NodeRef = Doc:AllocateElementByName("References",true);
    local References = tolua.cast(NodeRef, "tcReferences");
    tLuaLog("RefID="..refID);
    References:AddRefEntry(refID,refTypeID);
    TargetElement:AddChildOrdered(References);
    return 1;
  end
  return 0;
end

function AddSenseReference(TargetElement,refID,refSenseID,refTypeID)
  if TargetElement ~= nil then
    local NodeRef = Doc:AllocateElementByName("References",true);
    local References = tolua.cast(NodeRef, "tcReferences");
    References:AddRefSense(refID,refSenseID,refTypeID);
    TargetElement:AddChildOrdered(References);
    return 1;
  end
  return 0;
end

function AddEntry(Section,Lemma)
  if Section ~= nil and Lemma ~= nil then
    local NodeEntry = Doc:AllocateElementByID(NODE_ENTRY,true);
    local Entry = tolua.cast(NodeEntry, "tcEntry");
    Entry:SetLemmaSign(Lemma);
    local NewIndex = Section:InsertEntry(Entry);
    Evt_LemmasInserted:Trigger(nil, Section);
    return Section:GetEntry(NewIndex);
  end
  return nil;
end

function CheckEntryReferenceExists(TargetElement,refID,refTypeID)
  local indexE = 0;
  local indexR = 0;
  if TargetElement ~= nil then
    for indexE=0, TargetElement:GetNumChildrenOfElementType(ElementReferences:GetID())-1,1 do
      local References = tolua.cast(TargetElement:GetNthChildOfElementType(ElementReferences:GetID(),indexE), "tcReferences");
      local currentRefNum = References:GetNumRefEntries();
      for indexR=0, References:GetNumRefEntries()-1,1 do
        local currentRefID = References:GetRefEntryID(indexR);
        local currentRefType = References:GetRefType(indexR);
        if currentRefID == refID and currentRefType == refTypeID then
          return true;
        end
      end
    end
  end
  return false;
end

function CheckSenseReferenceExists(TargetElement,refID,refSenseID, refTypeID)
  local indexE = 0;
  local indexR = 0;
  if TargetElement ~= nil then
    for indexE=0, TargetElement:GetNumChildrenOfElementType(ElementReferences:GetID())-1,1 do
      local References = tolua.cast(TargetElement:GetNthChildOfElementType(ElementReferences:GetID(),indexE), "tcReferences");
      local currentRefNum = References:GetNumRefEntries();
      for indexR=0, References:GetNumRefEntries()-1,1 do
        local currentRefID = References:GetRefEntryID(indexR);
        local currentRefType = References:GetRefType(indexR);
        local currentRefSenseID = References:GetRefSenseID(currentRefID,indexR)
        if currentRefID == refID and currentRefType == refTypeID and currentRefSenseID == refSenseID then
          return true;
        end
      end
    end
  end
  return false;
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

function AddRefDetails(Parent, refDetails)
  local NodeRef = Doc:AllocateElementByName("References",true);
  local References = tolua.cast(NodeRef, "tcReferences");
  for key,value in pairs(refDetails) do
    if value['RefSenseID'] ~= nil then
      References:AddRefSense(value['RefEntryID'],value['RefSenseID'],value['RefTypeID']);
    else
      References:AddRefEntry(value['RefEntryID'],value['RefTypeID']);
    end
  end
  Parent:AddChildOrdered(References);
end

function PopulateFirstTwoAttributesFromRefLemmaAndDef(References)
  local Parent = References:GetParent();
  local attributeLemma = Parent:GetElement():GetAttribute(0);
  local attributeGloss = Parent:GetElement():GetAttribute(1);
  for rIndex=0, References:GetNumRefEntries()-1,1 do
    local refEntry = References:GetRefEntry(rIndex);
    Parent:SetAttributeDisplayByString(attributeLemma,refEntry:GetLemmaSign());
    local currentRefID = References:GetRefEntryID(rIndex);
    local refSense = References:GetRefSense(currentRefID, rIndex)
    if refSense == nil and refEntry:GetNumChildrenOfElementType(ElementSense:GetID()) > 0 then
      refSense = refEntry:GetNthChildOfElementType(ElementSense:GetID(),0);
    end
    if refSense ~= nil and tQuery(refSense, "/@ShortGloss") ~= nil and tQuery(refSense, "/@ShortGloss") ~= "" then
      Parent:SetAttributeDisplayByString(attributeGloss,tQuery(refSense, "/@ShortGloss"));
    else
      if refSense ~= nil and refSense:GetNumChildrenOfElementType(ElementDefinition:GetID()) > 0 then
        local refDef = refSense:GetNthChildOfElementType(ElementDefinition:GetID(),0);
        if refDef ~= nil then
          Parent:SetAttributeDisplayByString(attributeGloss,tQuery(refDef,"/@Definition"));
        end
      end
    end
  end
end

function GenerateMorphologyString(currentEntry)
  local eIndex=0;
  local mIndex=0;
  local rIndex=0;
  local morphologyString = "";
  for eIndex=0, currentEntry:GetNumChildrenOfElementType(ElementMorphology:GetID())-1,1 do
    if morphologyString ~= "" then
      morphologyString = morphologyString.." +";--between words
    end
    local Morphology = currentEntry:GetNthChildOfElementType(ElementMorphology:GetID(),eIndex);

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
          morphologyString = morphologyString.." '"..Morpheme:GetAttributeDisplayAsString(AttrGloss).."'";
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
          morphologyString = morphologyString.." "..refEntry:GetLemmaSign();
          if tQuery(refEntry,"/@StemHandle") ~= nil and tQuery(refEntry,"/@StemHandle") ~= "" then
            morphologyString = morphologyString.." '"..tQuery(refEntry,"/@StemHandle").."'";
          else
            local currentRefID = References:GetRefEntryID(rIndex);
            local refSense = References:GetRefSense(currentRefID, rIndex)
            if tQuery(refSense, "/@ShortGloss") ~= nil and tQuery(refSense, "/@ShortGloss") ~= "" then
              morphologyString = morphologyString.." '"..tQuery(refSense, "/@ShortGloss").."'";
            else
              local refDef = refSense:GetNthChildOfElementType(ElementDefinition:GetID(),0);
              if refDef ~= nil then
                morphologyString = morphologyString.." '"..tQuery(refDef,"/@Definition").."'";
              end
            end
          end
        end
      end
    end
  end
  currentEntry:SetAttributeDisplayByString(AttrMorphology,morphologyString);
  if currentEntry:HasChanged() == false then
    currentEntry:SetChanged(true,true);
  end
end


function AddCode(Entry, codeText)
  if tQuery(Entry,"/@Code") == "" then
    Entry:SetAttributeDisplayByString(AttrCode,codeText);
  else
    Entry:SetAttributeDisplayByString(AttrCode,tQuery(Entry,"/@Code").." "..codeText);
  end
end

function BetterLowerCase(str)
local i = 1;
local newString;
  for i=1,string.len(str),1 do
    local theChar = string.sub(str,i,i);
    local lowerTest = string.lower(theChar);
    if lowerTest ~= "" and lowerTest ~= nil then
      tLuaLog("test: ");
      if newString == nil then
        newString = lowerTest;
      else
        newString = newString..lowerTest;
      end
    else
      tLuaLog("char: ");
      if newString == nil then
        newString = theChar;
      else
        newString = newString..theChar;
      end
    end
    tLuaLog(newString);
  end
return newString;
end

function CreateLemmaReferences(Section)
  local sIndex=0;
  if Section ~= nil then
    for sIndex=0,Section:GetNumEntries()-1,1 do
      local SectionEntry = Section:GetEntry(sIndex);
      if tFrameWindow():GetSectionWindow(Section):IsTagged(SectionEntry) then
        local SectionLemma = Trim(tQuery(SectionEntry, "/@Lemma"));
        for SectionLemmaWord in string.gmatch(SectionLemma, "[^%s]+") do
          if LangLanguage:FindEntries(SectionLemmaWord):size() == 1 then
            local MatchedEntry = LangLanguage:FindEntries(SectionLemmaWord)[0];
            local FirstSense = LangLanguage:FindEntries(SectionLemmaWord)[0]:GetNthChildOfElementType(ElementSense:GetID(), 0);
            local LemmasNode = Doc:AllocateElementByName("Lemmas",true);
            SectionEntry:AddChildOrdered(LemmasNode);
            if FirstSense ~= nil then
              AddSenseReference(LemmasNode,LangLanguage:FindEntries(SectionLemmaWord)[0]:GetID(), FirstSense:GetID(),0);
              if tRequestModify(SectionEntry, true) then
                if SectionEntry:HasChanged() == false then
                  SectionEntry:SetChanged(true,true);
                end
              end
            end
          elseif LangLanguage:FindEntries(SectionLemmaWord):size() == 0 then
            local ReferencesCreated = false;
            --iterate through Inflected Forms, Derived Forms, Variant Forms
            for lIndex=0,LangLanguage:GetNumEntries()-1,1 do
              Entry = LangLanguage:GetEntry(lIndex);
              if ElementInflectedForm ~= nil then
                for eIndex=0,Entry:GetNumChildrenOfElementType(ElementInflectedForm:GetID())-1,1 do
                  local InflectedForm = Entry:GetNthChildOfElementType(ElementInflectedForm:GetID(),eIndex);
                  local InflectedFormText = tQuery(InflectedForm,"/@WordForm");
                  if InflectedFormText == SectionLemmaWord then
                    TLCLog("inflected form match "..SectionEntry:GetLemmaSign());
                    local FirstSense = Entry:GetNthChildOfElementType(ElementSense:GetID(), 0);
                    local LemmasNode = Doc:AllocateElementByName("Lemmas",true);
                    SectionEntry:AddChildOrdered(LemmasNode);
                    AddSenseReference(LemmasNode,Entry:GetID(), FirstSense:GetID(),0);
                    ReferencesCreated = true;
                    if tRequestModify(SectionEntry, true) then
                      if SectionEntry:HasChanged() == false then
                        SectionEntry:SetChanged(true,true);
                      end
                    end
                  end
                end
              end
              if ElementDerivedForm ~= nil then
                for eIndex=0,Entry:GetNumChildrenOfElementType(ElementDerivedForm:GetID())-1,1 do
                  local DerivedForm = Entry:GetNthChildOfElementType(ElementDerivedForm:GetID(),eIndex);
                  local DerivedFormText = tQuery(DerivedForm,"/@WordForm");
                  if DerivedFormText == SectionLemmaWord then
                    TLCLog("derived form match "..SectionEntry:GetLemmaSign());
                    local FirstSense = Entry:GetNthChildOfElementType(ElementSense:GetID(), 0);
                    local LemmasNode = Doc:AllocateElementByName("Lemmas",true);
                    SectionEntry:AddChildOrdered(LemmasNode);
                    AddSenseReference(LemmasNode,Entry:GetID(), FirstSense:GetID(),0);
                    ReferencesCreated = true;
                    if tRequestModify(SectionEntry, true) then
                      if SectionEntry:HasChanged() == false then
                        SectionEntry:SetChanged(true,true);
                      end
                    end
                  end
                end
              end
              if ElementVariantForm ~= nil then
                for eIndex=0,Entry:GetNumChildrenOfElementType(ElementVariantForm:GetID())-1,1 do
                  local VariantForm = Entry:GetNthChildOfElementType(ElementVariantForm:GetID(),eIndex);
                  local VariantFormText = tQuery(VariantForm,"/@WordForm");
                  if VariantFormText == SectionLemmaWord then
                    TLCLog("variant form match "..SectionEntry:GetLemmaSign());
                    local FirstSense = Entry:GetNthChildOfElementType(ElementSense:GetID(), 0);
                    local LemmasNode = Doc:AllocateElementByName("Lemmas",true);
                    SectionEntry:AddChildOrdered(LemmasNode);
                    AddSenseReference(LemmasNode,Entry:GetID(), FirstSense:GetID(),0);
                    ReferencesCreated = true;
                    if tRequestModify(SectionEntry, true) then
                      if SectionEntry:HasChanged() == false then
                        SectionEntry:SetChanged(true,true);
                      end
                    end
                  end
                end
              end
            end
            if ReferencesCreated == false then
              local LemmasNode = Doc:AllocateElementByName("Lemmas",true);
              SectionEntry:AddChildOrdered(LemmasNode);
              local RefNode = Doc:AllocateElementByName("References",true);
              local References = tolua.cast(RefNode, "tcReferences");
              LemmasNode:AddChildOrdered(References);
              local LemmaNode = Doc:AllocateElementByName("Lemma", true);
              LemmasNode:AddChildOrdered(LemmaNode);
              LemmaNode:SetAttributeDisplayByString(AttrLemmaText, "?");
              if tRequestModify(SectionEntry, true) then
                if SectionEntry:HasChanged() == false then
                  SectionEntry:SetChanged(true,true);
                end
              end
            end
          end
        end
      end
    end
  end
end

function TagEntries(Section, FilePath)
  local infile = io.open(FilePath, "r");
  local Entries = {}
  for line in infile:lines() do
    table.insert(Entries, line);
  end
  local count = 0;
  for k=1, #Entries,1 do
    local EntriesInSection = Section:FindEntries(Entries[k]);
    for j=0, EntriesInSection:size()-1,1 do
      tFrameWindow():GetSectionWindow(Section):Tag(EntriesInSection[j]);
      count = count+1;
    end
  end
  TLCLog("the number of tagged entries in "..Section:GetName().." is "..count);
end

function MatchTEWithinSense(reversalLemma,SenseDef)
  local TE;
  local sIndex;
  local dIndex;

  --SenseDef can be Sense or Def so mostly first loop should do it

  for sIndex=0, SenseDef:GetNumChildrenOfElementType(ElementTE:GetID())-1,1 do
    if tQuery(SenseDef:GetNthChildOfElementType(ElementTE:GetID(),sIndex),"/@TE") == reversalLemma then
      TE = SenseDef:GetNthChildOfElementType(ElementTE:GetID(),sIndex);
      break;
    end
  end
  if TE == nil then
    for sIndex=0, SenseDef:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
      local Definition = SenseDef:GetNthChildOfElementType(ElementDefinition:GetID(),sIndex);
      for dIndex=0, Definition:GetNumChildrenOfElementType(ElementTE:GetID())-1,1 do
        if tQuery(Definition:GetNthChildOfElementType(ElementTE:GetID(),sIndex),"/@TE") == reversalLemma then
          TE = Definition:GetNthChildOfElementType(ElementTE:GetID(),sIndex);
          break;
        end
      end
      if TE ~= nil then
        break;
      end
    end
  end
  return TE;
end

function GenerateDTDLangCommon(InputFile, OutputFile)
local writeLine = "";
local infile = io.open(InputFile, "r");
local Fields = {}
local Attributes = {};
local currentElement = "";
for line in infile:lines() do
  table.insert(Fields, line);
end
for k=1, #Fields,1 do
  if not string.find(Fields[k], "/") then
    currentElement = Fields[k];
    writeLine=writeLine.."Element"..Fields[k].." = Doc:GetDTD():FindElementByName(\""..Fields[k].."\");\n"
    .."if Element"..Fields[k].." == nil then return \""..Fields[k].." Element not found\"; end\n\n";
  else
    ParentNode = Split(Fields[k], "/")[1];
    ChildAttr = Split(Fields[k], "/")[2];
    local ChildAttrVar = "Attr"..ChildAttr;
    if Attributes[ChildAttrVar] == nil then
      Attributes[ChildAttrVar] = true;
    else
      ChildAttrVar = "Attr"..currentElement..ChildAttr;
      Attributes[ChildAttrVar] = true;
    end
    writeLine=writeLine..ChildAttrVar.." = Element"..ParentNode..":FindAttributeByName(\""..ChildAttr.."\");\n"
    .."if "..ChildAttrVar.." == nil then return \""..ChildAttrVar.." Attribute not found\"; end\n\n"
  end
end
local file = io.open(script_path().lang..OutputFile, "w+");
file:write(writeLine);
file:close();
end


function LevDistance(s1,s2) 
  local i,j,l1,l2,t,track;
  local dist = {}          -- create the matrix
    for i=0,50 do
     dist[i] = {}     -- create a new row
      for j=0,50 do
        dist[i][j] = 0
      end
    end
  l1 = string.len(s1);
  l2= string.len(s2);
  for i=0, l1, 1 do
    dist[0][i] = i;
  end
  for j=0, l2, 1 do
    dist[j][0] = j;
  end
  for j=1, l1, 1 do
    for i=1, l2, 1 do
      if s1[i-1] == s2[j-1] then
        track= 0;
      else
        track = 1;
      end
        t = math.min((dist[i-1][j]+1),(dist[i][j-1]+1));
        dist[i][j] = math.min(t,(dist[i-1][j-1]+track));
      end
  end
  return dist[l2][l1];
end

function recursiveNormalizeAllAttributes(Element,replacements)
  --replacements is table with keys being character to replace and values the replacement
  local eIndex = 0;
  local hasChange = false;
  --update all attributes
  if Element ~= nil then
    for eIndex=0,Element:GetElement():GetNumAttributes()-1,1 do
      tLuaLog("attrIndex="..eIndex);
      local curAttr = Element:GetElement():GetAttribute(eIndex);
      if curAttr ~= nil then
        local attrString = Element:GetAttributeDisplayAsString(curAttr);
        local normalized = attrString;
        for k,v in pairs(replacements) do
          normalized = tRegReplace(normalized,k,v);
        end
        if normalized ~= attrString then
          Element:SetAttributeDisplayByString(curAttr,normalized);
          hasChange = true;
        end
      end
    end
    --go to next child element
    for eIndex=0,Element:GetNumChildren()-1,1 do
      tLuaLog("elementIndex="..eIndex.." - "..Element:GetChild(eIndex):GetElement():GetName());
      local nextElement = Element:GetChild(eIndex);
      if recursiveNormalizeAllAttributes(nextElement,replacements) then
        hasChange = true;
      end
    end
  end
  return hasChange;
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
  tLuaLog("compareTable")
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v1 ~= v2 then
      return false
    end
  end
  return true
end

function MergeEntryToWordBank(Entry,DestEntry,Section)
  tLuaLog("MergeEntryToWordBank");
  local SenseMap = {};
  local countCloned = 0;
  local countSkipped = 0;
  local scriptFlag = "";
  local sIndex = 0;
  local i = 0;
  local ssIndex = 0;
  local lIndex = 0;
  local lIndexFix = 0;
  local eIndex = 0;
  local dIndex = 0;
  local rIndex = 0;
  local rIndexFix = 0;
  local rxIndex = 0;
  local xxIndex = 0;
  if DestEntry ~= nil then
    local DestEntryID = DestEntry:GetID();
    local SourceEntryID = Entry:GetID();
    if tRequestModify(Entry,true) and tRequestModify(DestEntry,true) then
      local didntClone = true;
  
      CleanTEReferencesForDelete(Entry);
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
        tLuaLog("untagging Entry");
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

        for eIndex=0, Entry:GetNumChildrenOfElementType(ElementCrossRef:GetID())-1,1 do
          local CrossRef = Entry:GetNthChildOfElementType(ElementCrossRef:GetID(),eIndex);
          local crossRefText = tQuery(CrossRef,"/@CrossRefText");
          local crossRefTexts = Split(crossRefText,";");
          for cfIndex = 1, #crossRefTexts, 1 do
            if CheckEntryForAttributeVal(DestEntry,ElementCrossRef:GetID(),"CrossRefText",crossRefTexts[cfIndex]) then
              --cf already exists
            else
              local CrossRefNode = Doc:AllocateElementByName("CrossRef",true);
              CrossRefNode:SetAttributeDisplayByString(AttrCrossRefText,crossRefTexts[cfIndex]);
              DestEntry:AddChildOrdered(CrossRefNode);
            end
          end
        end

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
    
    if countSkipped == 0 then
      DestEntry:SetAttributeDisplayByString(AttrScriptFlag,"");
    end
  else
    tLuaLog("entry nil");
  end
  Evt_LemmasInserted:Trigger(nil, Section);
  Evt_LemmaHomNumChanged:Trigger(nil, Section);
  Evt_EntryPreDelete:Trigger(nil, Section);
  Evt_NodeDeleteFromDoc:Trigger(nil, Section);
  return countSkipped;
end