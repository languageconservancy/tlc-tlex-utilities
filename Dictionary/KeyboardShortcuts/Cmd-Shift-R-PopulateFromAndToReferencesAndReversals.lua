--$LUA$:--01032025

-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton

  --Include Utility Functions
  tLuaLog("Start");
  local Doc=tApp():GetCurrentDoc();
  --make network compatible
  tRequestLoadAll();

  LangLanguage=Doc:GetDictionary():GetLanguage(0);
  EngLanguage=Doc:GetDictionary():GetLanguage(1);
  VerbLanguage=Doc:GetDictionary():GetLanguage(2);

  --Element/Attribute Declarations

  ElementSense = Doc:GetDTD():FindElementByName("Sense");
  if ElementSense == nil then return "Sense Element not found"; end
  ElementDefinition = Doc:GetDTD():FindElementByName("Definition");
  if ElementDefinition == nil then return "Definition Element not found"; end
  ElementTE = Doc:GetDTD():FindElementByName("TE");
  if ElementTE == nil then return "TE Element not found"; end
  AttrTE = ElementTE:FindAttributeByName("TE");
  if AttrTE == nil then return "TE Attribute not found"; end
  ElementSubentry = Doc:GetDTD():FindElementByName("Subentry");
  if ElementSubentry == nil then return "Subentry Element not found"; end
  AttrRevCategory = ElementSubentry:FindAttributeByName("RevCategory");
  if AttrRevCategory == nil then return "TECategory Attribute not found"; end
  AttrSubentryPOS = ElementSubentry:FindAttributeByName("PartOfSpeech");
  if AttrSubentryPOS == nil then return "PartOfSpeech Attribute not found"; end
  AttrInitDelChng = ElementTE:FindAttributeByName("InitDelChng");
  if AttrInitDelChng == nil then return "InitDelChng Attribute not found"; end
  ElementReferences = Doc:GetDTD():FindElementByName("References");
  if ElementReferences == nil then return "References Element not found"; end
  ElementReversalSense = Doc:GetDTD():FindElementByName("ReversalSense");
  if ElementReversalSense == nil then return "ReversalSense Element not found"; end
  ElementReversalDefinition = Doc:GetDTD():FindElementByName("ReversalDefinition");
  if ElementReversalDefinition == nil then return "ReversalDefinition Element not found"; end
  ElementAudioBank = Doc:GetDTD():FindElementByName("AudioBank");
  if ElementAudioBank == nil then return "AudioBank Element not found"; end
  ElementAudio = Doc:GetDTD():FindElementByName("Audio");
  if ElementAudio == nil then return "Audio Element not found"; end
  ElementCorpusDetails = Doc:GetDTD():FindElementByName("CorpusDetails");
  ElementInflectedForm = Doc:GetDTD():FindElementByName("InflectedForm");
  ElementInflectedForms = Doc:GetDTD():FindElementByName("InflectedForms");
  ElementExPhrase = Doc:GetDTD():FindElementByName("ExPhrase");
  ElementExample = Doc:GetDTD():FindElementByName("Example");
  ElementVariantForm = Doc:GetDTD():FindElementByName("VariantForm");
  ElementImage = Doc:GetDTD():FindElementByName("Image");

  --Utility Functions

  function AddEntry(Section,Lemma,HomNum)
    tLuaLog("AddEntry");
    if Section ~= nil and Lemma ~= nil then
      local NodeEntry = Doc:AllocateElementByID(NODE_ENTRY,true);
      local Entry = tolua.cast(NodeEntry, "tcEntry");
      Entry:SetLemmaSign(Lemma);
      if math.floor(HomNum) > 1 then
        Entry:SetHomNum(HomNum);
        tLuaLog("setting HomNum On new Entry: "..Lemma.." to "..HomNum);
      end
      local NewIndex = Section:InsertEntry(Entry);
      Evt_LemmasInserted:Trigger(nil, Section);
      return Section:GetEntry(NewIndex);
    end
    return nil;
  end

  function GetOrAddEntryOrSubEntryFromTE(TE)
    local teText = tQuery(TE,"/@TE");
    tLuaLog("GetOrAddEntryOrSubEntryFromTE: "..teText);
    local teInitDelChng = tQuery(TE,"/@InitDelChng");
    local teParent = TE:GetParent();
    local teHomNum = tQuery(TE,"/@HomonymNumber");
    if teHomNum == "" or teHomNum == "0" then
        teHomNum = "1";
    end
    local homNum = math.floor(teHomNum);
    local teCategory = tQuery(TE,"/@TECategory");
    local tePOS = tQuery(TE,"/@TEPartOfSpeech");
    local RevEntry = GetEntry(EngLanguage,teText,teHomNum);
    if RevEntry == nil then
      tLuaLog("Creating New Rev Entry");
      RevEntry = AddEntry(EngLanguage,teText,teHomNum);
      RevEntry:SetNew(true,true);
    else
      if tRequestModify(RevEntry, true) then
        tLuaLog("Entry Checkout Success");
      else
        tLuaLog("aborting due to checkout");
        return nil;
      end
    end
    if RevEntry ~= nil then
      
      if teCategory ~= "" or tePOS ~= "" then
        --we better worry about SubEntries
        tLuaLog("Subentry Handling");
        local foundSubentry = false;
        for rIndex = 0,RevEntry:GetNumChildrenOfElementType(ElementSubentry:GetID())-1,1 do
          local Subentry = RevEntry:GetNthChildOfElementType(ElementSubentry:GetID(),rIndex);
          if teCategory ~= "" and teCategory == tQuery(Subentry,"/@RevCategory") then
            RevEntry = Subentry;
            foundSubentry = true;
            tLuaLog("teCategory Subentry");
            break;
          end
          --if category set, pos is ignored
          if tePOS ~= "" and tePOS == tQuery(Subentry,"/PartOfSpeech") then
            RevEntry = Subentry;
            foundSubentry = true;
            tLuaLog("POS Subentry");
            break;
          end
        end
        if foundSubentry == false then
          --make subentry
          local SubentryNode = Doc:AllocateElementByName("Subentry");
          if teCategory ~= "" then
            SubentryNode:SetAttributeDisplayByString(AttrRevCategory,teCategory);
          end
          --if category set, pos is ignored
          if tePOS ~= "" then
            SubentryNode:SetAttributeDisplayByString(AttrSubentryPOS,tePOS);
          end
          RevEntry = RevEntry:GetChild(RevEntry:AddChildOrdered(SubentryNode));
        end
        if RevEntry:GetParent():HasChanged() == false then
          RevEntry:GetParent():SetChanged(true,true);
        end
      else
        if RevEntry:HasChanged() == false then
          RevEntry:SetChanged(true,true);
        end
      end
      
      return RevEntry;
    else
      return nil
    end
  end

  function GetEntry(Section,Lemma,HomNum)
    tLuaLog("GetEntry")
    local eIndex = 0;
    local Entries = Section:FindEntries(Lemma);
    tLuaLog("found "..Entries:size().." "..Lemma);
    for eIndex = 0, Entries:size()-1,1 do
      local Entry = Entries[eIndex];
      local LemmaHomNum = tQuery(Entry,"/@HomonymNumber");
      if LemmaHomNum == "" or LemmaHomNum == "0" then
        LemmaHomNum = "1";
      end
      tLuaLog("HomNums "..LemmaHomNum.." vs "..HomNum);
      if LemmaHomNum == HomNum then
        --we found the correct entry
        tLuaLog("found exact match");
        return Entry;
      end
    end
    tLuaLog("no matching entry");
    return nil;
  end

  function DeleteElement(Element)
    tLuaLog("DeleteElement");
    Element:PreDeleteFromDoc();
    Doc:DeleteTreeFromDoc(Element);
  end

  function DeleteEntry(Section, Entry)
    tLuaLog("DeleteElement");
    Entry = tolua.cast(Entry,"tcEntry");
    Entry:PreDeleteFromDoc();
    tFrameWindow():GetSectionWindow(Section):EntryDelete(Entry,true);
  end

  function recursiveMove(newParent, elementToMove)
    tLuaLog("recursiveMove");
    local newElement = recursiveClone(newParent, elementToMove);
    elementToMove:PreDeleteFromDoc();
    Doc:DeleteTreeFromDoc(elementToMove);
    return newElement;
  end

  function recursiveClone(newParent,elementToClone)
    tLuaLog("recursiveClone");
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
        recursiveClone(NodeNew,elementToClone:GetChild(rcindex));
      end
      --tLuaLog("add new element of type"..elementName);
      local ElementNew = newParent:GetChild(newParent:AddChildOrdered(NodeNew));
      --tLuaLog("return newParent");
      return ElementNew;
  end

  function recursiveGetParentEntryOrSubentry(Element)
    tLuaLog("recursiveGetParentEntryOrSubentry");
    if Element:GetParent() ~= nil then
      if Element:GetParent():GetElement():GetName() == "Subentry" then
        return Element:GetParent();
      end
    end
    if Element:GetParent() == nil or Element:GetElement():GetName() == "Entry" then
      return tolua.cast(Element, "tcEntry");
    else
      return recursiveGetParentEntryOrSubentry(Element:GetParent());
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

  function CopyAFewAudioBankAudiosToElement(Entry,AudioRecipient)
    tLuaLog("CopyAFewAudioBankAudiosToElement");
    local audioCount = 0;
    local eIndex = 0;
    if Entry:GetNumChildrenOfElementType(ElementAudio:GetID()) > 0 then
      for eIndex=0,Entry:GetNumChildrenOfElementType(ElementAudio:GetID())-1,1 do
        local Audio = Entry:GetNthChildOfElementType(ElementAudio:GetID(),eIndex);
        recursiveClone(AudioRecipient,Audio);
        audioCount = audioCount + 1;
      end
    else
      if Entry:GetNumChildrenOfElementType(ElementAudioBank:GetID()) > 0 then
        local AudioBank = Entry:GetNthChildOfElementType(ElementAudioBank:GetID(),0);
        local abIndex = 0;
        local foundMaleAudio = false;
        local foundFemaleAudio = false;
        for abIndex = 0, AudioBank:GetNumChildrenOfElementType(ElementAudio:GetID())-1,1 do
            local Audio = AudioBank:GetNthChildOfElementType(ElementAudio:GetID(),abIndex);
            if Trim(tQuery(Audio,"/@Code")) == "" then-- and audioCount <= 4 then
              recursiveClone(AudioRecipient,Audio);
              audioCount = audioCount + 1;
            end
            --[[if starts_with(tQuery(Audio,"/@Gender"),"M") and foundMaleAudio == false then
                recursiveClone(AudioRecipient,Audio);
                foundMaleAudio = true;
            end 
            if starts_with(tQuery(Audio,"/@Gender"),"F") and foundFemaleAudio == false then
                recursiveClone(AudioRecipient,Audio);
                foundFemaleAudio = true;
            end
            if starts_with(tQuery(Audio,"/@Speaker"),"ENM") or starts_with(tQuery(Audio,"/@Speaker"),"LNJ") then
                recursiveClone(AudioRecipient,Audio);
            end]]
        end
      end 
    end
  end

  function CopyInflectedFormToElement(Entry,Recipient)
    tLuaLog("CopyInflectedFormToElement");
    for eIndex=0,Entry:GetNumChildrenOfElementType(ElementInflectedForm:GetID())-1,1 do
      local InflectedForm = Entry:GetNthChildOfElementType(ElementInflectedForm:GetID(),eIndex);
      recursiveClone(Recipient,InflectedForm);
    end 
  end
  function CopyInflectedFormsToElement(Entry,Recipient)
    tLuaLog("CopyInflectedFormsToElement");
    for eIndex=0,Entry:GetNumChildrenOfElementType(ElementInflectedForms:GetID())-1,1 do
      local InflectedForms = Entry:GetNthChildOfElementType(ElementInflectedForms:GetID(),eIndex);
      recursiveClone(Recipient,InflectedForms);
    end 
  end

  function CopyVariantFormsToElement(Entry,VariantRecipient)
    tLuaLog("CopyVariantFormsToElement");
    local eIndex = 0;
    for eIndex=0,Entry:GetNumChildrenOfElementType(ElementVariantForm:GetID())-1,1 do
      local VariantForm = Entry:GetNthChildOfElementType(ElementVariantForm:GetID(),eIndex);
      recursiveClone(VariantRecipient,VariantForm);
    end 
  end

  function CopySenseImagesToElement(Entry,Recipient)
    tLuaLog("CopySenseImagesToElement");
    local Lemma = tQuery(recursiveGetParentEntryOrSubentry(Recipient),"/@Lemma");
    local eIndex = 0;
    local sIndex = 0;
    for eIndex=0,Entry:GetNumChildrenOfElementType(ElementSense:GetID())-1,1 do
      local Sense = Entry:GetNthChildOfElementType(ElementSense:GetID(),eIndex);
      if MatchTEWithinSense(Lemma,Sense) ~= nil then
        for sIndex=0,Sense:GetNumChildrenOfElementType(ElementImage:GetID())-1,1 do
          local Image = Sense:GetNthChildOfElementType(ElementImage:GetID(),sIndex);
          recursiveClone(Recipient,Image);
        end
      end
    end
  end

  function Trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
  end

  function CopyEntryAttributesAndChildrenToRevSense(Entry,ReversalSense)
    tLuaLog("CopyEntryAttributesAndChildrenToRevSense");
    CopyAttributesToNonIdenticalElement(Entry,ReversalSense);--setting the lemma
    DeleteAudioChildren(ReversalSense);
    CopyAFewAudioBankAudiosToElement(Entry,ReversalSense);
    DeleteElementChildren(ReversalSense, ElementInflectedForm);
    CopyInflectedFormToElement(Entry,ReversalSense);
    if ElementExPhrase ~= nil then
      DeleteElementChildren(ReversalSense, ElementExPhrase);
      CopyExPhraseToElement(Entry,ReversalSense);
    end
    if ElementExample ~= nil then
      DeleteElementChildren(ReversalSense, ElementExample);
      CopyExampleToElement(Entry,ReversalSense);
    end
    if ElementHistoricalForm ~= nil then
      DeleteElementChildren(ReversalSense, ElementHistoricalForm);
      CopyHistoricalFormToElement(Entry,ReversalSense);
    end
    if ElementImage ~= nil then
      DeleteElementChildren(ReversalSense, ElementImage);
      CopySenseImagesToElement(Entry,ReversalSense);
    end
    DeleteElementChildren(ReversalSense, ElementVariantForm);
    CopyVariantFormsToElement(Entry,ReversalSense);
  end

  function GetRevSense(RevEntry,TE)
    tLuaLog("GetRevSense");
    --just seeing if reversal sense with matching lemma and homnum exists
    local eIndex = 0;
    local teEntry = recursiveGetParentEntryOrSubentry(TE);
    if teEntry ~= nil then
      local lemma = tQuery(teEntry,"/@Lemma");
      local homNum = tQuery(teEntry,"/@HomonymNumber");
      if homNum == "" or homNum == "0" then
        homNum = "1";
      end
      for eIndex=0,RevEntry:GetNumChildrenOfElementType(ElementReversalSense:GetID())-1,1 do
        local ReversalSense = RevEntry:GetNthChildOfElementType(ElementReversalSense:GetID(),eIndex);
        local revHomNum = tQuery(ReversalSense,"/@HomonymNumber");
        if revHomNum == "" or revHomNum == "0" then
          revHomNum = "1";
        end
        if revHomNum == homNum and tQuery(ReversalSense,"/@Lemma") == lemma then
          return ReversalSense;
        end
      end
    end
    return nil;
  end

  --for init
  function CreateRevEntryAndRevSenseFromTE(teEntry,TE)
    tLuaLog("CreateRevEntryAndRevSenseFromTE");
    local RevEntry = GetOrAddEntryOrSubEntryFromTE(TE);
    local ReversalSense = GetRevSense(RevEntry,TE);
    if ReversalSense == nil then
      local NodeReversalSense = Doc:AllocateElementByName("ReversalSense");
      CopyEntryAttributesAndChildrenToRevSense(teEntry,NodeReversalSense);
      ReversalSense = RevEntry:GetChild(RevEntry:AddChildOrdered(NodeReversalSense));
    else
      CopyEntryAttributesAndChildrenToRevSense(teEntry,ReversalSense);
    end
    return ReversalSense;
  end

  function CopyElementsToNonIdenticalParent(Donor, Recipient)
    tLuaLog("CopyElementsToNonIdenticalParent");
    local dIndex = 0;
    local rIndex = 0;
    local cIndex = 0;
    for dIndex=0, Donor:GetElement():GetNumChildren()-1,1 do
      local DonorChildElement = Donor:GetElement():GetChildElement(dIndex);
      if DonorChildElement:GetName() ~= "References" and DonorChildElement:GetName() ~= "Audio" then
        for rIndex=0,Recipient:GetElement():GetNumChildren()-1,1 do
          local RecipientChildElement = Recipient:GetElement():GetChildElement(rIndex);
          if DonorChildElement:GetName() == RecipientChildElement:GetName() then
            DeleteElementChildren(Recipient,RecipientChildElement);
            for cIndex=0,Donor:GetNumChildrenOfElementType(DonorChildElement:GetID())-1,1 do
              recursiveClone(Recipient,Donor:GetNthChildOfElementType(DonorChildElement:GetID(),cIndex));
            end
          end
        end
      end
    end
  end

  --for cloning attributes to revSense and revDef
  function CopyAttributesToNonIdenticalElement(Element,Recipient)
    tLuaLog("CopyAttributesToNonIdenticalElement");
    local elIndex = 0;
    for elIndex=0, Element:GetElement():GetNumAttributes()-1,1 do
      local elementAttr = Element:GetElement():GetAttribute(elIndex);
      local recipientAttr = Recipient:GetElement():FindAttributeByName(elementAttr:GetName());
      tLuaLog("SetAttr:"..elementAttr:GetName());
      if elementAttr ~= nil and recipientAttr ~= nil then
        Recipient:SetAttributeDisplayByString(recipientAttr,Element:GetAttributeDisplayAsString(elementAttr));
      end
    end
    if Element:GetElement():GetName() == "Sense" or Element:GetElement():GetName() == "Definition" then
      CopyUsageLabelToAppropriateElement(Element,Recipient);
    end
  end

  function CopyUsageLabelToAppropriateElement(Element, Recipient)
    tLuaLog("CopyUsageLabelToAppropriateElement");
    local usageLabel = tQuery(Element,"/@UsageLabel");
    if usageLabel == nil or usageLabel == "" then
      local Parent = Element:GetParent();
      usageLabel = tQuery(Parent,"/@UsageLabel");
    end
    if usageLabel ~= nil and usageLabel ~= "" then
      local attrUseLab = Recipient:GetElement():FindAttributeByName("UsageLabel");
      if attrUseLab ~= nil then
        Recipient:SetAttributeDisplayByString(attrUseLab,usageLabel);
        tLuaLog("usageLabel written")
      end
    end
  end

  --string function
  function starts_with(str, start)
    return str:sub(1, #start) == start
  end

  function AddSenseReference(TargetElement,refID,refSenseID,refTypeID)
    tLuaLog("AddSenseReference");
    if TargetElement ~= nil then
      local NodeRef = Doc:AllocateElementByName("References",true);
      local References = tolua.cast(NodeRef, "tcReferences");
      References:AddRefSense(refID,refSenseID,refTypeID);
      TargetElement:AddChildOrdered(References);
      return 1;
    end
    return 0;
  end

  function AddEntryReference(TargetElement,refID,refTypeID)
    tLuaLog("AddEntryReference");
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

  --used in clone for reference maintenance
  function GetReferencesDetails(References)
    tLuaLog("GetReferenceDetails");
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

  --used in clone for reference maintenance
  function RestoreRefDetails(References, refDetails)
    tLuaLog("RestoreRefDetails");
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

  --finds TE for a given ReversalLemma
  function MatchTEWithinSense(reversalLemma,SenseDef)
    tLuaLog("MatchTEWithinSense");
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

  function DeleteAudioChildren(AudioParent)
    local pIndex = 0;
    local pIndexFix = 0;
    for pIndex = 0, AudioParent:GetNumChildrenOfElementType(ElementAudio:GetID())-1, 1 do
      local Audio = AudioParent:GetNthChildOfElementType(ElementAudio:GetID(),pIndex-pIndexFix);
      Audio:PreDeleteFromDoc();
      Doc:DeleteTreeFromDoc(Audio);
      pIndexFix = pIndexFix + 1;
    end
  end

  function DeleteElementChildren(Parent,ElementTypeDeclaration)
    local pIndex = 0;
    local pIndexFix = 0;
    for pIndex = 0, Parent:GetNumChildrenOfElementType(ElementTypeDeclaration:GetID())-1, 1 do
      local Element = Parent:GetNthChildOfElementType(ElementTypeDeclaration:GetID(),pIndex-pIndexFix);
      Element:PreDeleteFromDoc();
      Doc:DeleteTreeFromDoc(Element);
      pIndexFix = pIndexFix + 1;
    end
  end


  function PopulateFirstTwoAttributesFromRefLemmaAndDef(References)
    local Parent = References:GetParent();
    local attributeLemma = Parent:GetElement():GetAttribute(0);
    local attributeGloss = Parent:GetElement():GetAttribute(1);
    for rIndex=0, References:GetNumRefEntries()-1,1 do
      local refEntry = References:GetRefEntry(rIndex);
      Parent:SetAttributeDisplayByString(attributeLemma,refEntry:GetLemmaSign());
      
      if recursiveGetParentEntryOrSubentry(References) ~= refEntry then
        --Handle Sense Ref
        local currentRefID = References:GetRefEntryID(rIndex);
        local refSense = References:GetRefSense(currentRefID, rIndex)
        if refSense == nil and refEntry:GetNumChildrenOfElementType(ElementSense:GetID()) > 0 then
            refSense = refEntry:GetNthChildOfElementType(ElementSense:GetID(),0);
        end
        --Gather Sense Def
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
        --could source from corpusDetails
        --this is mostly a cowlitz detector for special handling
        if ElementCorpusDetails ~= nil then
          if refEntry:GetNumChildrenOfElementType(ElementCorpusDetails:GetID()) > 0 then
            local ParentType = Parent:GetElement():GetName();
            local ElementParent = Doc:GetDTD():FindElementByName(ParentType);
            local corpusDetails = refEntry:GetNthChildOfElementType(ElementCorpusDetails:GetID(),0);
            if refSense == nil then
              Parent:SetAttributeDisplayByString(attributeGloss,tQuery(corpusDetails,"/@Translation"));
            end
            if tQuery(corpusDetails,"/@UncrtSpelling") ~= "" then
              local AttrUncrtSpelling = ElementParent:FindAttributeByName("UncrtSpelling");
              if AttrUncrtSpelling ~= nil then
                Parent:SetAttributeDisplayByString(AttrUncrtSpelling,tQuery(corpusDetails,"/@UncrtSpelling"));
              end
            end
            if tQuery(corpusDetails,"/@UncrtTranslation") ~= "" then
              local AttrUncrtTranslation = ElementParent:FindAttributeByName("UncrtTranslation");
              if AttrUncrtTranslation ~= nil then
                Parent:SetAttributeDisplayByString(AttrUncrtTranslation,tQuery(corpusDetails,"/@UncrtTranslation"));
              end
            end
            
            ---corpus entry level
            
            if tQuery(refEntry,"/@FormType") ~= "" then
              local AttrFormType = ElementParent:FindAttributeByName("FormType");
              if AttrUncrtTranslation ~= nil then
                Parent:SetAttributeDisplayByString(AttrUncrtTranslation,tQuery(refEntry,"/@FormType"));
              end
            end
            if tQuery(refEntry,"/@GrammaticalLabel") ~= "" then
              local AttrGrammaticalLabel = ElementParent:FindAttributeByName("GrammaticalLabel");
              if AttrGrammaticalLabel ~= nil then
                Parent:SetAttributeDisplayByString(AttrGrammaticalLabel,tQuery(refEntry,"/@GrammaticalLabel"));
              end
            end
            if tQuery(refEntry,"/@GrammaticalLabel") ~= "" then
              local AttrGrammarNote = ElementParent:FindAttributeByName("GrammarNote");
              if AttrGrammarNote ~= nil then
                Parent:SetAttributeDisplayByString(AttrGrammarNote,tQuery(refEntry,"/@GrammaticalLabel"));
              end
            end
          end
        end

      CopyElementsToNonIdenticalParent(refEntry,Parent);
      end
      --Audio From AudioBank
      DeleteAudioChildren(Parent);
      if refEntry:GetNumChildrenOfElementType(ElementAudio:GetID()) > 0 then
        for eIndex=0,refEntry:GetNumChildrenOfElementType(ElementAudio:GetID())-1,1 do
          local Audio = refEntry:GetNthChildOfElementType(ElementAudio:GetID(),eIndex);
          recursiveClone(Parent,Audio);
        end
      else
        if refEntry:GetNumChildrenOfElementType(ElementAudioBank:GetID()) > 0 then
          local AudioBank = refEntry:GetNthChildOfElementType(ElementAudioBank:GetID(),0);
          local abIndex = 0;
          local foundMaleAudio = false;
          local foundFemaleAudio = false;
          for abIndex = 0, AudioBank:GetNumChildrenOfElementType(ElementAudio:GetID())-1,1 do
            local Audio = AudioBank:GetNthChildOfElementType(ElementAudio:GetID(),abIndex);
            -- if starts_with(tQuery(Audio,"/@Gender"),"M") and foundMaleAudio == false then
            --     recursiveClone(Parent,Audio);
            --     foundMaleAudio = true;
            -- end 
            -- if starts_with(tQuery(Audio,"/@Gender"),"F") and foundFemaleAudio == false then
            --     recursiveClone(Parent,Audio);
            --     foundFemaleAudio = true;
            -- end
            -- if starts_with(tQuery(Audio,"/@Speaker"),"ENM") or starts_with(tQuery(Audio,"/@Speaker"),"LNJ") then
            --   recursiveClone(Parent,Audio);
            -- end
            recursiveClone(Parent,Audio);
          end
        end
      end
      CopyAttributesToNonIdenticalElement(refEntry,Parent);
    end
  end

  --just makes a nice object of standard TE variables
  function TEtoStruct(TE)
    tLuaLog("TEtoStruct");
    local struct = {};
    struct["InitDelChng"] = tQuery(TE,"/@InitDelChng");
    struct["TE"] = tQuery(TE,"/@TE");
    struct["HomonymNumber"] = tQuery(TE,"/@HomonymNumber");
    struct["TEPos"] = tQuery(TE,"/@TEPos");
    struct["TECategory"] = tQuery(TE,"/@TECategory");
    for k,v in pairs(struct) do tLuaLog(k.." = "..v) end
    return struct;
  end

  --if parent has 1 child then can just delete parent all the way up to deleting Reversal entry
  function recursiveDeleteEmptyUpChain(Element)
    tLuaLog("recursiveDeleteEmptyUpChain");
    tLuaLog(Element:GetParent():GetNumChildren().." vs "..Element:GetParent():GetNumChildrenOfElementType(ElementAudio:GetID()));
    if Element:GetParent():GetNumChildren() - Element:GetParent():GetNumChildrenOfElementType(ElementAudio:GetID()) - Element:GetParent():GetNumChildrenOfElementType(ElementVariantForm:GetID()) - Element:GetParent():GetNumChildrenOfElementType(ElementInflectedForm:GetID()) == 1 then
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

  function PopulateReversalFromTE(TE)
    tLuaLog("PopulateReversalFromTE");
    local teDonor = recursiveGetParentEntryOrSubentry(TE);
    local teEntry = recursiveGetParentEntry(TE);
    local teParent = TE:GetParent();
    local struct = TEtoStruct(TE);
    local hasRef = TE:GetNumChildrenOfElementType(ElementReferences:GetID()) > 0;
    tLuaLog("hasRef="..tostring(hasRef));
    if struct["InitDelChng"] == "Initialize" and hasRef == false then
      tLuaLog("Initialize!");
      --no references exist so time to create everything
      local RevSense = CreateRevEntryAndRevSenseFromTE(teDonor,TE);
      if teParent:GetElement():GetName() == "Sense" then
        --add reference at reversalsense
        AddSenseReference(RevSense,teEntry:GetID(),teParent:GetID(),1);
        AddSenseReference(TE,recursiveGetParentEntry(RevSense):GetID(),RevSense:GetID(),1);
        --then add all definitions
        local sIndex = 0;
        for sIndex = 0,teParent:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
          local nodeRevDef = Doc:AllocateElementByName("ReversalDefinition");
          local Definition = teParent:GetNthChildOfElementType(ElementDefinition:GetID(),sIndex);
          CopyAttributesToNonIdenticalElement(Definition,nodeRevDef);
          RevSense:AddChildOrdered(nodeRevDef);
        end
      end
      if teParent:GetElement():GetName() == "Definition" then
        
        local nodeRevDef = Doc:AllocateElementByName("ReversalDefinition");
        CopyAttributesToNonIdenticalElement(teParent,nodeRevDef);
        local ReversalDefinition = RevSense:GetChild(RevSense:AddChildOrdered(nodeRevDef));
        --reference goes on the revDef
        AddSenseReference(ReversalDefinition,teEntry:GetID(),teParent:GetID(),1);
        AddSenseReference(TE,recursiveGetParentEntry(RevSense):GetID(),ReversalDefinition:GetID(),1);
      end
      if teParent:GetElement():GetName() == "Entry" then
        
        --reference goes on the RevSense
        AddEntryReference(RevSense,teEntry:GetID(),1);
        AddSenseReference(TE,recursiveGetParentEntry(RevSense):GetID(),RevSense:GetID(),1);
      end

      
    else
      local References = tolua.cast(TE:GetNthChildOfElementType(ElementReferences:GetID(),0),"tcReferences");
      local refSenseDef;
      if References:GetNumRefEntries() > 0 then
        refSenseDef = References:GetRefSense(References:GetRefEntryID(0),0);
        --refSenseDef could be ReversalSense or ReversalDefinition
      end
      local teParent = TE:GetParent();
        --teParent could be Sense or Definition
      if refSenseDef ~= nil then
        local refSenseDefEntry = recursiveGetParentEntry(refSenseDef);
        tLuaLog("ref points to "..refSenseDefEntry:GetLemmaSign());
        if struct["InitDelChng"] == "" then
          tLuaLog("Normal Update!");
          if tRequestModify(teEntry, true) then
            --follow reference and update content
            local RevEntry = GetOrAddEntryOrSubEntryFromTE(TE);
            if refSenseDef:GetElement():GetName() == "ReversalSense" then
              --this means teParent is a Sense
              CopyEntryAttributesAndChildrenToRevSense(teDonor,refSenseDef);
              DeleteElementChildren(refSenseDef,ElementReversalDefinition);
              local tpIndex = 0;
              for tpIndex = 0,teParent:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
                local Definition = teParent:GetNthChildOfElementType(ElementDefinition:GetID(),tpIndex);
                local nodeRevDef = Doc:AllocateElementByName("ReversalDefinition");
                CopyAttributesToNonIdenticalElement(Definition,nodeRevDef);
                refSenseDef:AddChildOrdered(nodeRevDef);
              end
            else
              if refSenseDef:GetElement():GetName() == "ReversalDefinition" then
                --parent is Def
                local revSense = refSenseDef:GetParent();
                CopyEntryAttributesAndChildrenToRevSense(teDonor,revSense);
                CopyAttributesToNonIdenticalElement(teParent,refSenseDef);
              else
                tLuaLog("detected malformed refSenseDef: "..refSenseDef:GetElement():GetName());
              end
            end
            if RevEntry ~= nil and isRevEntryDeleted == false then
              if RevEntry:HasChanged() == false then
                RevEntry:SetChanged(true,true);
              end
            end
          end
        end
        if struct["InitDelChng"] == "Change" then
          tLuaLog("Change!");
          if tRequestModify(teEntry, true) then
            --follow reference and move accordingly
            DeleteElementChildren(TE,ElementReferences);
            local refSenseDefParent = refSenseDef:GetParent();
            if refSenseDef:GetElement():GetName() == "ReversalSense" then
              --going to move this revSense to its new home
              local RevEntry = GetOrAddEntryOrSubEntryFromTE(TE);
              if RevEntry ~= nil then
                CopyEntryAttributesAndChildrenToRevSense(teDonor,refSenseDef);
                DeleteElementChildren(refSenseDef,ElementReversalDefinition);
                local tpIndex = 0;
                for tpIndex = 0,teParent:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
                  local teDef = teParent:GetNthChildOfElementType(ElementDefinition:GetID(),tpIndex);
                  local nodeRevDef = Doc:AllocateElementByName("ReversalDefinition");
                  CopyAttributesToNonIdenticalElement(teDef,nodeRevDef);
                  refSenseDef:AddChildOrdered(nodeRevDef);
                end
                refSenseDef = recursiveMove(RevEntry,refSenseDef);
                AddSenseReference(TE,recursiveGetParentEntry(refSenseDef):GetID(),refSenseDef:GetID(),1);
                local isRevEntryDeleted = false;
                if refSenseDefParent:GetNumChildren() == 0 then
                  isRevEntryDeleted = recursiveDeleteEmptyUpChain(refSenseDefParent);
                end
                if RevEntry:GetElement():GetName() == "Subentry" then
                  RevEntry = RevEntry:GetParent();
                end
                if RevEntry ~= nil and isRevEntryDeleted == false then
                  if RevEntry:HasChanged() == false then
                    RevEntry:SetChanged(true,true);
                  end
                end
                tLuaLog("Clearing InitDelChng");
                TE:SetAttributeListID(AttrInitDelChng,0);
                if teEntry:HasChanged() == false then
                  teEntry:SetChanged(true,true);
                end
                if refSenseDefEntry ~= nil then
                  if refSenseDefEntry:HasChanged() == false then
                    refSenseDefEntry:SetChanged(true,true);
                  end
                end
                return 1;
              end
            else
              if refSenseDef:GetElement():GetName() == "ReversalDefinition" then
                --update def attributes
                CopyAttributesToNonIdenticalElement(teParent,refSenseDef);
                --going to move revDef to its new home
                --teParent is Definition
                local RevEntry = GetOrAddEntryOrSubEntryFromTE(TE);
                local RevSense = GetRevSense(RevEntry,TE);
                if RevSense == nil then
                  RevSense = CreateRevEntryAndRevSenseFromTE(teDonor,TE);
                end

                refSenseDef = recursiveMove(RevSense,refSenseDef);
                AddSenseReference(TE,recursiveGetParentEntry(refSenseDef):GetID(),refSenseDef:GetID(),1);
                local isRevEntryDeleted = false;
                if refSenseDefParent:GetNumChildren() - refSenseDefParent:GetNumChildrenOfElementType(ElementAudio:GetID()) - refSenseDefParent:GetNumChildrenOfElementType(ElementVariantForm:GetID()) - refSenseDefParent:GetNumChildrenOfElementType(ElementInflectedForm:GetID()) == 0 then
                  isRevEntryDeleted = recursiveDeleteEmptyUpChain(refSenseDefParent);
                end
                if RevEntry:GetElement():GetName() == "Subentry" then
                  RevEntry = RevEntry:GetParent();
                end
                if RevEntry ~= nil and isRevEntryDeleted == false then
                  if RevEntry:HasChanged() == false then
                    RevEntry:SetChanged(true,true);
                  end
                end
                tLuaLog("Clearing InitDelChng");
                TE:SetAttributeListID(AttrInitDelChng,0);
                if teEntry:HasChanged() == false then
                  teEntry:SetChanged(true,true);
                end
                if refSenseDefEntry ~= nil then
                  if refSenseDefEntry:HasChanged() == false then
                    refSenseDefEntry:SetChanged(true,true);
                  end
                end
                return 1;
              end
            end
          end
        end
        if refSenseDefEntry ~= nil then
          if refSenseDefEntry:HasChanged() == false then
            refSenseDefEntry:SetChanged(true,true);
          end
        end
        if struct["InitDelChng"] == "Delete" then
          if tRequestModify(teEntry, true) then
            tLuaLog("Delete!");
            --follow reference and delete
            local RevEntry = recursiveGetParentEntry(refSenseDef);
            local isRevEntryDeleted = recursiveDeleteEmptyUpChain(refSenseDef);
            if isRevEntryDeleted == false and RevEntry ~= nil and RevEntry:GetElement():GetName() == "Entry" then
              if RevEntry:HasChanged() == false then
                RevEntry:SetChanged(true,true);
              end
            end
            if teEntry:HasChanged() == false then
              teEntry:SetChanged(true,true);
            end
            DeleteElement(TE);
            return 1
          end
        end
      end
    end
    tLuaLog("Clearing InitDelChng");
    TE:SetAttributeListID(AttrInitDelChng,0);
    if teEntry ~= nil then
      if teEntry:HasChanged() == false then
        teEntry:SetChanged(true,true);
      end
    end
    return 0;
  end

  function PopulateReversalFromNonSenseTE(TE)
    --this clones element over and then destroys all references, replacing with a backrefence on TE to the source entry
    --this could be simplified in future to just be the reference that sources it if that system becomes complete
    tLuaLog("PopulateReversalFromNonSenseTE");
    local teEntry = recursiveGetParentEntryOrSubentry(TE);
    local teParent = TE:GetParent();
    local struct = TEtoStruct(TE);
    local hasRef = TE:GetNumChildrenOfElementType(ElementReferences:GetID()) > 0;
    tLuaLog("hasRef="..tostring(hasRef));
    if struct["InitDelChng"] == "Initialize" and hasRef == false then
    else
      if struct["InitDelChng"] == "" then
        tLuaLog("Normal Update!");
      end
      if struct["InitDelChng"] == "Change" then
        tLuaLog("Change is ILLEGAL HERE!");
      end
      if struct["InitDelChng"] == "Delete" then
        tLuaLog("Delete!");
      end
    end
  end



  --START HERE!--
  tLuaLog("starting");
  local countSkipped = 0;
  local lIndex = 0;
  local sIndex = 0;
  local rIndex = 0;
  local eIndex = 0;
  local seIndex = 0;
  if tFrameWindow():GetSectionWindow(gCurrentEntry:GetParent()):IsTagged(gCurrentEntry) then
    --THIS POPULATES REVERSALS CONNECTED TO gCurrentEntry OR UPDATES CURRENT ENTRY IF gCurrentEntry IS A REVERSAL
    if tRequestModify(gCurrentEntry, true) then
      tLuaLog("checkout out "..gCurrentEntry:GetLemmaSign());
      local currentSection = gCurrentEntry:GetParent();
      
      ---FROM THE ENGLISH SIDE
      if currentSection == Doc:GetDictionary():GetLanguage(1) then
        tLuaLog("From English Side");
        --we are working from a reversal to the main entries
        local eIndexFix = 0;
        for eIndex=0, gCurrentEntry:GetNumChildren()-1,1 do
        --walk through each reversalsense
          local elementName = gCurrentEntry:GetChild(eIndex-eIndexFix):GetElement():GetName();
          if elementName == "ReversalSense" then
          --Follow reference to the Sense/Def
          --Continue with populating based on State
            local RevSense = gCurrentEntry:GetChild(eIndex-eIndexFix);
            tLuaLog("Checking RevSense for References");
            if RevSense:GetNumChildrenOfElementType(ElementReferences:GetID()) > 0 then
              local ref = tolua.cast(RevSense:GetNthChildOfElementType(ElementReferences:GetID(),0),"tcReferences");
              if ref:GetNumRefEntries() > 0 then
                local RefSenseDef = ref:GetRefSense(ref:GetRefEntryID(0),0);
                --this is either Def or Sense
                if RefSenseDef == nil then
                  --just delete...not well formed
                  recursiveDeleteEmptyUpChain(RevSense);
                  eIndexFix = eIndexFix + 1;
                else
                  --either TE is in Sense or Definitions
                  local TE = MatchTEWithinSense(gCurrentEntry:GetLemmaSign(),RefSenseDef);
                  if TE ~= nil then
                    tLuaLog("either TE is in Sense or Definitions");
                    PopulateReversalFromTE(TE);
                  else
                    tLuaLog("failed to match TE within Sense");
                  end
                end
              end
            else
              for sIndex=0, RevSense:GetNumChildrenOfElementType(ElementReversalDefinition:GetID())-1,1 do
                local RevDef = RevSense:GetNthChildOfElementType(ElementReversalDefinition:GetID(),sIndex);
                tLuaLog("Checking RevDef for References");
                if RevDef:GetNumChildrenOfElementType(ElementReferences:GetID()) > 0 then
                  local ref = tolua.cast(RevDef:GetNthChildOfElementType(ElementReferences:GetID(),0),"tcReferences");
                  if ref:GetNumRefEntries() > 0 then
                    local RefSenseDef = ref:GetRefSense(ref:GetRefEntryID(0),0);
                    --this is either Def or Sense
                    if RefSenseDef == nil then
                      --just delete...not well formed
                      recursiveDeleteEmptyUpChain(RevDef);
                      eIndexFix = eIndexFix + 1;
                    else
                      --either TE is in Sense or Definitions
                      local TE = MatchTEWithinSense(gCurrentEntry:GetLemmaSign(),RefSenseDef);
                      if TE ~= nil then
                        tLuaLog("either TE is in Sense or Definitions");
                        PopulateReversalFromTE(TE);
                      else
                        tLuaLog("failed to match TE within Sense from Def");
                      end
                    end
                  end
                end
              end
            end
          end
          if elementName == "Subentry" then
            tLuaLog("In Reversal Subentry");
            local Subentry = gCurrentEntry:GetChild(eIndex);
            local seIndexFix = 0;
            for seIndex=0, Subentry:GetNumChildren()-1,1 do
              --walk through each reversalsense
                local elementName = gCurrentEntry:GetChild(seIndex-seIndexFix):GetElement():GetName();
              if elementName == "ReversalSense" then
              --Follow reference to the Sense/Def
              --Continue with populating based on State
                local RevSense = gCurrentEntry:GetChild(seIndex-seIndexFix);
                if RevSense:GetNumChildrenOfElementType(ElementReferences:GetID()) > 0 then
                  local ref = tolua.cast(RevSense:GetNthChildOfElementType(ElementReferences:GetID(),0),"tcReferences");
                  if ref:GetNumRefEntries() > 0 then
                    local RefSenseDef = ref:GetRefSense(ref:GetRefEntryID(0),0);
                    if RefSenseDef == nil then
                      --just delete...not well formed
                      DeleteElement(RevSense);
                      seIndexFix = seIndexFix + 1;
                    else
                      --either TE is in Sense or Definition
                      local TE = MatchTEWithinSense(gCurrentEntry:GetLemmaSign(),RefSenseDef);
                      if TE ~= nil then
                        PopulateReversalFromTE(TE);
                      end
                    end
                  end
                else
                  --references must be in defs
                  local rsIndex = 0;
                  for rsIndex=0,RevSense:GetNumChildrenOfElementType(ElementReversalDefinition:GetID())-1,1 do
                    local RevDef = RevSense:GetNthChildOfElementType(ElementReversalDefinition:GetID(),rsIndex);
                    if RevDef:GetNumChildrenOfElementType(ElementReferences:GetID()) > 0 then
                      local ref = tolua.cast(RevDef:GetNthChildOfElementType(ElementReferences:GetID(),0),"tcReferences");
                      if ref:GetNumRefEntries() > 0 then
                        local RefSenseDef = ref:GetRefSense(ref:GetRefEntryID(0),0);
                        if RefSenseDef == nil then
                          --just delete...not well formed
                          DeleteElement(RevSense);
                          seIndexFix = seIndexFix + 1;
                        else
                          --either TE is in Sense or Definition
                          local TE = MatchTEWithinSense(gCurrentEntry:GetLemmaSign(),RefSenseDef);
                          if TE ~= nil then
                            PopulateReversalFromTE(TE);
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      else
        --TO THE ENGLISH SIDE
        tLuaLog("Not English Side");
        local eIndexFix = 0;
        local dIndex;
        local seIndex;
        local seIndexFix = 0;
        --entry level TE means from verb side, but might use this for apache dialect distribution
        for eIndex=0, gCurrentEntry:GetNumChildrenOfElementType(ElementTE:GetID())-1,1 do
          local TE = gCurrentEntry:GetNthChildOfElementType(ElementTE:GetID(),eIndex-eIndexFix);
          tLuaLog("TE is in Entry");
          eIndexFix = eIndexFix + PopulateReversalFromTE(TE);
        end
        for eIndex=0, gCurrentEntry:GetNumChildren()-1,1 do
          local elementName = gCurrentEntry:GetChild(eIndex-eIndexFix):GetElement():GetName();
          if elementName == "Sense" then
            local Sense = gCurrentEntry:GetChild(eIndex-eIndexFix);
            sIndexFix = 0;
            for sIndex=0, Sense:GetNumChildrenOfElementType(ElementTE:GetID())-1,1 do
              local TE = Sense:GetNthChildOfElementType(ElementTE:GetID(),sIndex-sIndexFix);
              tLuaLog("TE is in Sense");
              sIndexFix = sIndexFix + PopulateReversalFromTE(TE);
            end
            sIndexFix = 0;
            for sIndex=0, Sense:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
              local Definition = Sense:GetNthChildOfElementType(ElementDefinition:GetID(),sIndex-sIndexFix);
              dIndexFix = 0
              for dIndex=0, Definition:GetNumChildrenOfElementType(ElementTE:GetID())-1,1 do
                local TE = Definition:GetNthChildOfElementType(ElementTE:GetID(),dIndex-dIndexFix);
                tLuaLog("TE is in Definition");
                dIndexFix = dIndexFix + PopulateReversalFromTE(TE);
              end
            end
          end
          if elementName == "Subentry" then
            local Subentry = gCurrentEntry:GetChild(eIndex-eIndexFix);
            for seIndex = 0, Subentry:GetNumChildren()-1,1 do
              local seElementName = Subentry:GetChild(seIndex-seIndexFix):GetElement():GetName();
              if seElementName == "Sense" then
                local Sense = Subentry:GetChild(seIndex-seIndexFix);
                sIndexFix = 0;
                for sIndex=0, Sense:GetNumChildrenOfElementType(ElementTE:GetID())-1,1 do
                  local TE = Sense:GetNthChildOfElementType(ElementTE:GetID(),sIndex-sIndexFix);
                  tLuaLog("TE is in Sense");
                  sIndexFix = sIndexFix + PopulateReversalFromTE(TE);
                end
                sIndexFix = 0;
                for sIndex=0, Sense:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
                  local Definition = Sense:GetNthChildOfElementType(ElementDefinition:GetID(),sIndex-sIndexFix);
                  dIndexFix = 0
                  for dIndex=0, Definition:GetNumChildrenOfElementType(ElementTE:GetID())-1,1 do
                    local TE = Definition:GetNthChildOfElementType(ElementTE:GetID(),dIndex-dIndexFix);
                    tLuaLog("TE is in Definition");
                    dIndexFix = dIndexFix + PopulateReversalFromTE(TE);
                  end
                end
              end
            end
          end
        end
      end
    end

    --THIS UPDATES PARTS OF ENTRY REFERENCED TO OTHER ENTRIES

    tLuaLog("checking out "..gCurrentEntry:GetLemmaSign());
    if tRequestModify(gCurrentEntry, true) then
        for rIndex=0, gCurrentEntry:GetNumDescendantsOfElementType(ElementReferences:GetID())-1,1 do
            local refNode = gCurrentEntry:GetNthDescendantOfElementType(ElementReferences:GetID(), rIndex);
            local References = tolua.cast(refNode, "tcReferences");
            local Parent = References:GetParent();
            local parentName = Parent:GetElement():GetName();
            --handle Example, ExPhrase, CrossRef, InflectedForm, VariantForm, DerivedForm
            tLuaLog("checking "..parentName);
                
            if parentName=="Example" or parentName=="ExPhrase" or parentName=="CrossRef" or parentName=="InflectedForm" or parentName=="VariantForm" or parentName=="DerivedForm" or parentName=="DerivedForms" or parentName=="Morpheme" then
                tLuaLog("populating "..parentName);
                PopulateFirstTwoAttributesFromRefLemmaAndDef(References);
                if gCurrentEntry:HasChanged() == false then
                    gCurrentEntry:SetChanged(true,true);
                end
            end
        end
    end


    --THIS PART POPULATES ENTRIES REFERENCED TO ENTRY BEING EDITED

    local targetID = gCurrentEntry:GetID();
    local refTable = {};
    for sIndex=0, Doc:GetDictionary():GetNumSections()-1,1 do
        local Section = Doc:GetDictionary():GetLanguage(sIndex);
        for lIndex=0,Section:GetNumEntries()-1,1 do
            Entry = Section:GetEntry(lIndex);
            if refTable[Entry:GetLemmaSign()] == nil then
                refTable[Entry:GetLemmaSign()] = {};
            end
            for eIndex=0, Entry:GetNumDescendantsOfElementType(ElementReferences:GetID())-1,1 do
                local References = tolua.cast(Entry:GetNthDescendantOfElementType(ElementReferences:GetID(),eIndex),"tcReferences");
                if References:GetNumRefEntries() > 0 and References:GetRefEntryID(0)==targetID then
                    table.insert(refTable[Entry:GetLemmaSign()],References:GetRefEntryID(0));
                    local Parent = References:GetParent();
                    local parentName = Parent:GetElement():GetName();
                    --handle Example, ExPhrase, CrossRef, InflectedForm, VariantForm, DerivedForm
                    tLuaLog("checking "..parentName);
                    if parentName=="Example" or parentName=="ExPhrase" or parentName=="CrossRef" or parentName=="InflectedForm" or parentName=="VariantForm" or parentName=="DerivedForm" then
                        tLuaLog("populating "..parentName);
                        local refEntry = References:GetRefEntry(0)
                        if tRequestModify(refEntry, true) then
                          PopulateFirstTwoAttributesFromRefLemmaAndDef(References);
                          if refEntry:HasChanged() == false then
                            refEntry:SetChanged(true,true);
                          end
                        end
                    end
                end
            end
        end
    end


    Evt_LemmasInserted:Trigger(nil, EngLanguage);
    Evt_EntryPreDelete:Trigger(nil, EngLanguage);
    Evt_NodeDeleteFromDoc:Trigger(nil, EngLanguage);
    Evt_NodeDeleteFromDoc:Trigger(nil, LangLanguage);
    Doc:SetDirty();
  end
  return "done";