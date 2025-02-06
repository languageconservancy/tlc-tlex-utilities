-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

--2025 The Language Conservancy
--Elliot Thornton
--Update Reversals and Sense IDs

--Using TE entries attached to Definitions on Language(0) side,
--populate Reversal Headwords and attache Lemma and Definition IDs.

--make network compatible

--basic header
tRequestLoadAll();
tLuaLog("Loaded Dictionary Common");
Doc=tApp():GetCurrentDoc();
if Doc==nil then return "Open a dictionary silly 🤪";end

--get both sides of dictionary
LangLanguage=Doc:GetDictionary():GetLanguage(0);
EngLanguage=Doc:GetDictionary():GetLanguage(1);
Corpus=Doc:GetDictionary():GetLanguage(2);
MorphemesSection=Doc:GetDictionary():GetLanguage(3);
if LangLanguage==nil or EngLanguage==nil then return "Dictionary must have 2 languages!";end

function testCommon()
  return "testCommon() Success"
end

testCommonString = "testCommonString Success";

--DTD --Use GenerateDTDLangCommon.lua to create the declarations and paste below
