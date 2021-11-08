-- ---------------------------------------------------------------------------------------------------------------------
--
-- Copyright (c) 2021 Rico Engelmann
-- unofficial MoneyMoney Web Banking Extension for Mensamax
-- http://moneymoney-app.com/api/webbanking
--
--
-- The MIT License (MIT)
--
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
-- ---------------------------------------------------------------------------------------------------------------------

WebBanking{
           version     = 1.00,
           url         = "https://mammasmensa.de",
           services    = {"Mensamax"},
           description = "Mensamax Umsaetze und Kontostand"
         }

local var_dateMap = {}
var_dateMap["Januar"] = "01.01."
var_dateMap["Februar"] = "01.02."
var_dateMap["März"] = "01.03."
var_dateMap["April"] = "01.04."
var_dateMap["Mai"] = "01.05."
var_dateMap["Juni"] = "01.06."
var_dateMap["Juli"] = "01.07."
var_dateMap["August"] = "01.08."
var_dateMap["September"] = "01.09."
var_dateMap["Oktober"] = "01.10."
var_dateMap["November"] = "01.11."
var_dateMap["Dezember"] = "01.12."

local var_project= "HH222"
local var_einrichtung="FARMSEN"
local var_username

local url_login="https://mammasmensa.de/?projekt="..var_project.."&einrichtung="..var_einrichtung
local url_account="https://mammasmensa.de/mensamax/MeineDaten/KontostandForm.aspx"
local connection = Connection()

-- ---------------------------------------------------------------------------------------------------------------------
--parseAccountNumber
-- returns the accountNumber
function getAccountNumber()
  return var_username
end

-- ---------------------------------------------------------------------------------------------------------------------
--parseOwner
--  at the moment static value
function getOwner()
  return var_username
end

-- ---------------------------------------------------------------------------------------------------------------------
--parseBalance
--  parse the balance out of the accountstatementPage
function parseBalance(html)
  text = html:xpath("//input[@id='tbxKontostand']"):attr("value")
  position_start=1
  position_end=string.find(text,"€", position_start)-1
  balance=string.sub(text,position_start,position_end)
  balance=string.gsub(balance,",",".")
  return tonumber(balance)
end

-- ---------------------------------------------------------------------------------------------------------------------
--getHTML
--  returns the html and html_text
function getHTML(url)
  local html_txt
  local html
  html = HTML(connection:get(url))
  html_txt=html:html()
  return html, html_txt
end


-- ---------------------------------------------------------------------------------------------------------------------
local function strToAmount(str)
    -- Helper function for converting localized amount strings to Lua numbers.
    local convertedValue = string.gsub(string.gsub(string.gsub(str, " .+", ""), "%.", ""), ",", ".")
    return convertedValue
end

-- ---------------------------------------------------------------------------------------------------------------------
local function strToFullDate (str)
    -- Helper function for converting localized date strings to timestamps.
    local d, m, y = string.match(str, "(%d%d).(%d%d).(%d%d%d%d)")
    return os.time{year=y, month=m, day=d}
end


-- ---------------------------------------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------------------------------------
-- MAIN PART - interfaces for MoneyMoney
-- ---------------------------------------------------------------------------------------------------------------------


function SupportsBank (protocol, bankCode)
  print("SupportsBank_mensamax")
  return protocol == ProtocolWebBanking and bankCode == "Mensamax"
end

-- ---------------------------------------------------------------------------------------------------------------------
function InitializeSession (protocol, bankCode, username, customer, password)
  print("InitializeSession_mensamax")
  var_username=username
  -- Login.
  html = getHTML(url_login)
  html:xpath('//input[@id="tbxBenutzername"]'):attr('value', username)
  html:xpath('//input[@id="tbxKennwort"]'):attr('value', password)
  html = HTML(connection:request(html:xpath('//input[@name="btnLogin"]'):click()))

    if html:xpath('//input[@id="tbxBenutzername"]'):length() > 0 then
     -- We are still at the login screen.
     return "Failed to log in. Please check your user credentials."
    end
  end


-- ---------------------------------------------------------------------------------------------------------------------
function ListAccounts (knownAccounts)
 print("ListAccounts")

  -- Return array of accounts.
  local account = {
    name = "Mensamax",
    owner = getAccountNumber(),
    accountNumber=getAccountNumber(),
    bankCode = "012345",
    currency = "EUR",
    type = AccountTypeOther
  }
  return {account}
end


-- ---------------------------------------------------------------------------------------------------------------------
function RefreshAccount (account, since)
  local transactions = {}
  local html,html_txt=getHTML(url_account)
  balance=parseBalance(html)

  -- Check if the HTML table with transactions exists.
    if html:xpath("//table[@id='tblEinzahlungen']/tbody/tr[1]/td[1]"):length() > 0 then

            -- Extract transactions.
            html:xpath("//table[@id='tblEinzahlungen']/tbody/tr[position()>0]"):each(function (index, row)
                local columns = row:children()
                local tmpDate=columns:get(1):text()
                local tmpAmount
                if tmpDate and string.len(tmpDate) > 0 then
                   tmpDate=var_dateMap[tmpDate]
                   tmpYear=columns:get(2):text()
                   tmpAmount=columns:get(3):text()
                  local transaction = {
                    valueDate   = strToFullDate(tmpDate..tmpYear),
                    bookingDate = strToFullDate(tmpDate..tmpYear),
                    purpose     = "Einzahlung", true,
                    currency    = "EUR",
                    amount      = strToAmount(tmpAmount)
                  }
                 table.insert(transactions, transaction)
               end
            end)

    end


      -- Check if the HTML table with transactions exists.
        if html:xpath("//table[@id='tblAusgaben']/tbody/tr[1]/td[1]"):length() > 0 then

                -- Extract transactions.
                html:xpath("//table[@id='tblAusgaben']/tbody/tr[position()>0]"):each(function (index, row)
                    columns = row:children()
                    tmpDate=columns:get(1):text()

                    if tmpDate and string.len(tmpDate) > 0 then
                       tmpDate=var_dateMap[tmpDate]
                       tmpYear=columns:get(2):text()
                       tmpAmount=columns:get(3):text()
                      local transaction = {
                        valueDate   = strToFullDate(tmpDate..tmpYear),
                        bookingDate = strToFullDate(tmpDate..tmpYear),
                        purpose     = "Leistung", true,
                        currency    = "EUR",
                        amount      = strToAmount(tmpAmount)*-1
                      }
                     table.insert(transactions, transaction)
                   end
                end)

        end

  -- Return balance and array of transactions.
  return {balance=balance, transactions=transactions}
end

function EndSession ()
  -- Logout.
end
