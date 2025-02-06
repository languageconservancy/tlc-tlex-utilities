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

for lIndex=0,LangLanguage:GetNumEntries()-1,1 do
  local Entry = LangLanguage:GetEntry(lIndex);
  eIndexFix = 0;
  for eIndex=0,Entry:GetNumDescendantsOfElementType(ElementTE:GetID())-1,1 do
    local TE = Entry:GetNthDescendantOfElementType(ElementTE:GetID(),eIndex - eIndexFix);
    if Trim(tQuery(TE, "/@TE")) == "" and tRequestModify(Entry, true) then
      TE:PreDeleteFromDoc();
      Doc:DeleteTreeFromDoc(TE);
      eIndexFix = eIndexFix + 1;
      if Entry:HasChanged() == false then
        Entry:SetChanged(true,true);
      end
    end
  end
end

Doc:SetDirty();
return "success";
