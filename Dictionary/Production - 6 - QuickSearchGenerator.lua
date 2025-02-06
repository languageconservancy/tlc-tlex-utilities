-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton


--Using TE entries attached to Definitions on Language(0) side,
--populate Reversal Headwords and attache Lemma and Definition IDs.

--make network compatible


--Include Utility Functions
tRequestLoadAll();
tLuaLog("Start");

function script_path()
  local script_paths = {};
  local str = debug.getinfo(2, "S").source:sub(2)
  script_paths['lang'] = str:match("(.*/)") or str:match("(.*[/\\])");
  script_paths['global'] = string.gsub(script_paths.lang,"[a-zA-Z ]+[/\\]$","");
  script_paths['delim'] = str:match("(/)") or str:match("([/\\])");
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
local sIndex = 0;
local dIndex = 0;
local revCSV = "id,rev,hom_number,rev_entry,enc_entry,short_gloss,def_len,sort\n";
local langCSV = "id,lx,hom_number,lx_entry,enc_entry,short_gloss,disclaimer,sort\n";
local quickSearch = "id,query,entry,short_gloss,hom_number,lx_id,rev_id,entry_id,is_appox,is_full_text,is_morpheme\n";
local qsID = 1;
local id = "";
local k;
local v;
local sort=1;

for lIndex=0,LangLanguage:GetNumEntries()-1,1 do
  local lx="";
  local approx="";
  local hom_number="";
  local lx_entry="";
  local full_text="";
  local short_gloss="";
  local disclaimer="";
  local morphology="";
  Entry = LangLanguage:GetEntry(lIndex);
  if tFrameWindow():GetSectionWindow(LangLanguage):IsTagged(Entry) then
    lx = Entry:GetLemmaSign();
    tLuaLog("lx: "..lx);
    full_text = full_text.." "..lx;
    id = Entry:GetID();
    local formCount = 0;
    local forms = {};
    hom_number = tQuery(Entry,"/@HomonymNumber");
    morphology = tQuery(Entry,"/@Morphology");
    full_text = full_text.." "..morphology;


    --gather all defs for shortgloss
    for eIndex=0,Entry:GetNumChildrenOfElementType(ElementSense:GetID())-1,1 do
      local Sense = Entry:GetNthChildOfElementType(ElementSense:GetID(),eIndex);
      for sIndex=0,Sense:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
        local Definition = Sense:GetNthChildOfElementType(ElementDefinition:GetID(),sIndex);
        if short_gloss ~= "" then
          short_gloss = short_gloss..", ";
        end
        short_gloss = short_gloss..tQuery(Definition,"/@Definition");
        full_text = full_text.." "..short_gloss;
      end
    end
    for eIndex=0,Entry:GetNumChildrenOfElementType(ElementSense:GetID())-1,1 do
      local Sense = Entry:GetNthChildOfElementType(ElementSense:GetID(),eIndex);
      for sIndex=0,Sense:GetNumChildrenOfElementType(ElementDefinition:GetID())-1,1 do
        local Definition = Sense:GetNthChildOfElementType(ElementDefinition:GetID(),sIndex);
        if sIndex == 0 then
          quickSearch = quickSearch..qsID..",\""..string.gsub(lx.." '"..tQuery(Definition,"/@Definition").."'","\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,1,0\n";
          qsID=qsID + 1;
        end
      end
    end
    langCSV = langCSV..id..",\""..string.gsub(lx,"\"","\"\"").."\","..hom_number..",,,\""..string.gsub(short_gloss,"\"","\"\"").."\",,"..sort.."\n";
    quickSearch = quickSearch..qsID..",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,0,0\n";
    qsID = qsID+1;
    sort = sort + 1;


    --gather all morphemes
    morphemesTable = Split(morphology, "  ");
    for i=1,#morphemesTable,1 do
      quickSearch = quickSearch..qsID..",\""..string.gsub(morphemesTable[i],"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,1,0\n";
      qsID = qsID+1;
    end

    --gather all semantic domain data
    for eIndex=0,Entry:GetNumDescendantsOfElementType(ElementSemanticDomain:GetID())-1,1 do
      local SemanticDomain = Entry:GetNthDescendantOfElementType(ElementSemanticDomain:GetID(), eIndex);
      local SemDomLabel = tQuery(SemanticDomain, "/@SemDomLabel");
      local SemDomIndex = tQuery(SemanticDomain, "/@SemDomIndex");
      if SemDomLabel ~= "" then
        full_text = full_text.." ".."Topic: "..SemDomLabel;
        quickSearch = quickSearch..qsID..",\""..string.gsub("Topic: "..SemDomLabel,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,0,1\n";
        qsID = qsID+1;
        if SemDomIndex ~= "" then
          quickSearch = quickSearch..qsID..",\""..string.gsub("Topic: "..SemDomIndex,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,0,1\n";
         qsID = qsID+1;
        end
      end
    end

    --gather all inflected forms, variants, headword
    if tQuery(Entry,"/@Code") ~= "VERBGEN" then
      for eIndex=0,Entry:GetNumDescendantsOfElementType(ElementInflectedForm:GetID())-1,1 do
        local InflectedForm = Entry:GetNthDescendantOfElementType(ElementInflectedForm:GetID(),eIndex);
        local wordForm = tQuery(InflectedForm,"/@WordForm");
        local formTranslation = tQuery(InflectedForm,"/@Translation");
        if wordForm ~= "" then
          forms[formCount] = wordForm;
          full_text = full_text.." "..wordForm;
          formCount = formCount + 1;
          quickSearch = quickSearch..qsID..",\""..string.gsub(wordForm,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,0,0\n";
          qsID = qsID+1;
        end
      end
      -- for eIndex=0,Entry:GetNumChildrenOfElementType(ElementDerivedForm:GetID())-1,1 do
      --   local DerivedForm = Entry:GetNthChildOfElementType(ElementDerivedForm:GetID(),eIndex);
      --   local wordForm = tQuery(DerivedForm,"/@WordForm");
      --   local formTranslation = tQuery(DerivedForm,"/@Translation");
      --   if wordForm ~= "" then
      --     forms[formCount] = wordForm;
      --     full_text = full_text.." "..wordForm;
      --     formCount = formCount + 1;
      --     quickSearch = quickSearch..qsID..",\""..string.gsub(wordForm,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(formTranslation,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,0,0\n";
      --     qsID = qsID+1;
      --   end
      -- end
    end
    for eIndex=0,Entry:GetNumDescendantsOfElementType(ElementVariantForm:GetID())-1,1 do
      local VariantForm = Entry:GetNthDescendantOfElementType(ElementVariantForm:GetID(),eIndex);
      local wordForm = tQuery(VariantForm,"/@WordForm");
      if wordForm ~= "" then
        forms[formCount] = wordForm;
        full_text = full_text.." "..wordForm;
        formCount = formCount + 1;
        quickSearch = quickSearch..qsID..",\""..string.gsub(wordForm,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,0,0\n";
        qsID = qsID+1;
      end
    end
    for eIndex=0,Entry:GetNumDescendantsOfElementType(ElementExPhrase:GetID())-1,1 do
      local Example = Entry:GetNthDescendantOfElementType(ElementExPhrase:GetID(),eIndex);
      local exampleText = tQuery(Example,"/@ExPhrase");
      full_text = full_text.." "..exampleText;
      full_text = full_text.." "..tQuery(Example,"/@Translation");
      if exampleText ~= "" then
        tLuaLog("Example: "..exampleText);
        local pattern = "[^%s]*"..lx.."[^%s]*";
        tLuaLog("ptrn: "..pattern);
        for v in string.gmatch(exampleText,pattern) do
          if v ~= nil then
            tLuaLog("lxMatch: "..v);
            quickSearch = quickSearch..qsID..",\""..string.gsub(v,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,0,0\n";
            qsID = qsID+1;
          end
        end
        local fIndex=0;
        for fIndex = 0, formCount-1, 1 do
          local pattern = "[^%s]*"..forms[fIndex].."[^%s]*";
          tLuaLog("ptrn: "..pattern);
          for v in string.gmatch(exampleText, pattern) do
            if v ~= nil then
              tLuaLog("formMatch: "..v);
              quickSearch = quickSearch..qsID..",\""..string.gsub(v,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,0,0\n";
              qsID = qsID+1;
            end
          end
        end
      end
      --quickSearch = quickSearch..qsID..",\""..string.gsub(exampleText,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,0,0";
      --qsID = qsID+1;
    end
    quickSearch = quickSearch..qsID..",\""..string.gsub(full_text,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\","..id..",0,"..id..",0,1,0,0\n";
    qsID = qsID+1;
    tLuaLog("forms: "..formCount);
  end
end

sort=1;
for lIndex=0,EngLanguage:GetNumEntries()-1,1 do
  local lx="";
  local approx="";
  local hom_number="";
  local lx_entry="";
  local full_text="";
  local short_gloss="";
  local disclaimer="";
  local morphology="";
  Entry = EngLanguage:GetEntry(lIndex);
  if tFrameWindow():GetSectionWindow(EngLanguage):IsTagged(Entry) then
    lx = Entry:GetLemmaSign();
    tLuaLog("rev: "..lx);
    id = Entry:GetID();
    local formCount = 0;
    local forms = {};
    hom_number = tQuery(Entry,"/@HomonymNumber");
    --gather all defs for shortgloss
    for eIndex=0,Entry:GetNumChildrenOfElementType(ElementReversalSense:GetID())-1,1 do
      local RevSense = Entry:GetNthChildOfElementType(ElementReversalSense:GetID(),eIndex);
      if tQuery(RevSense,"/@DoNotInclude") ~= "DNI" then
        if short_gloss ~= "" then
          short_gloss = short_gloss..", ";
        end
        short_gloss = short_gloss..tQuery(RevSense,"/@Lemma");
      end
    end
    revCSV = revCSV..id..",\""..string.gsub(lx,"\"","\"\"").."\","..hom_number..",,,\""..string.gsub(short_gloss,"\"","\"\"").."\",,"..sort.."\n";

    quickSearch = quickSearch..qsID..",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\",0,"..id..","..id..",0,0,0,0\n";
    qsID = qsID+1;
    sort = sort + 1;
for eIndex=0,Entry:GetNumChildrenOfElementType(ElementReversalSense:GetID())-1,1 do
      local RevSense = Entry:GetNthChildOfElementType(ElementReversalSense:GetID(),eIndex);
      for rsIndex=0,RevSense:GetNumChildrenOfElementType(ElementReversalDefinition:GetID())-1,1 do
        local RevDef = RevSense:GetNthChildOfElementType(ElementReversalDefinition:GetID(),rsIndex);
        local RevDefText = tQuery(RevDef,"/@Definition");
        if Trim(RevDefText) ~= Trim(lx) then
          quickSearch = quickSearch..qsID..",\""..string.gsub(Trim(RevDefText),"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(lx,"\"","\"\"").."\",\""..string.gsub(short_gloss,"\"","\"\"").."\",\""..hom_number.."\",0,"..id..","..id..",0,0,0,0\n";
          qsID = qsID+1;
        end
      end
    end
  end
end
local file = io.open(script_path().lang.."Export"..script_path().delim.."quickSearch.csv", "w+");
file:write(quickSearch);
file:close();
local file = io.open(script_path().lang.."Export"..script_path().delim.."revEntries.csv", "w+");
file:write(revCSV);
file:close();
local file = io.open(script_path().lang.."Export"..script_path().delim.."langEntries.csv", "w+");
file:write(langCSV);
file:close();
return "done";
