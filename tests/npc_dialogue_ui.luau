-- Real dialogue renderer/events; GUI engine layout types come from Roblox.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local R=require("@lune/roblox")
local checks,now=0,0
local function check(value,message)checks+=1;assert(value,message)end
local function signal()
    local callbacks={}
    local self={}
    function self:Connect(callback)
        local entry={Callback=callback,Connected=true};table.insert(callbacks,entry)
        return {Disconnect=function()entry.Connected=false end}
    end
    function self:Fire(...)
        for _,entry in ipairs(table.clone(callbacks)) do if entry.Connected then entry.Callback(...) end end
    end
    return self
end
local methods={}
local function new(class)
    local p={ClassName=class,Name=class,Children={},Visible=true,Activated=signal(),CanvasPosition=R.Vector2.zero}
    return setmetatable({}, {
        __index=function(_,key)return methods[key] or p[key]end,
        __newindex=function(self,key,value)
            if key=="Parent" then
                if p.Parent then
                    local index=table.find(p.Parent.Children,self);if index then table.remove(p.Parent.Children,index)end
                end
                p.Parent=value;if value then table.insert(value.Children,self)end
            else p[key]=value end
        end,
    })
end
function methods:IsA(class)return self.ClassName==class end
function methods:GetChildren()return table.clone(self.Children)end
function methods:FindFirstChild(name)for _,child in ipairs(self.Children)do if child.Name==name then return child end end end
function methods:Destroy()for _,child in ipairs(self:GetChildren())do child:Destroy()end;self.Parent=nil end
local theme=luau.load(fs.readFile("src/shared/VisualTheme.luau"),{environment={Color3=R.Color3}})()
local input=signal()
local UI=luau.load(fs.readFile("src/client/NPCDialogue.luau"),{environment={
    game={GetService=function(_,name)
        if name=="UserInputService" then return{InputBegan=input}end
        return{WaitForChild=function()return{WaitForChild=function()return"VisualTheme"end}end}
    end},
    require=function(name)assert(name=="VisualTheme");return theme end,
    Instance={new=new},UDim=R.UDim,UDim2=R.UDim2,Vector2=R.Vector2,
    Color3=R.Color3,Enum=R.Enum,os={clock=function()return now end},
}})()
local gui=new("ScreenGui")
local sent,opens,closes={},0,0
local allowed=true
local ui=UI.new(gui,function(...)table.insert(sent,{...})end,{
    CanOpen=function()return allowed end,OnOpen=function()opens+=1 end,OnClose=function()closes+=1 end,
})
local function payload(session)
    return {Id="merchant_cove",Session=session or"server-session-1",Name="Мара",Role="Скупщик и поручения",
        Text="Привет! Рыбакам нужна помощь. Поручения выдаю раз в день, награду забери у меня.",
        Choices={{Id="quests",Text="Какие поручения?"},{Id="claim",Text="Сдать выполненное",Enabled=false},
            {Id="trade",Text="Продать улов"},{Id="close",Text="До встречи"}}}
end
check(not ui:IsOpen(),"conversation starts hidden")
ui:Handle("Dialogue",{})
check(not ui:IsOpen(),"malformed payload does not open UI")
allowed=false;ui:Handle("Dialogue",payload())
check(not ui:IsOpen() and sent[1][3]=="close","busy gameplay refuses the server session cleanly")
allowed=true;ui:Handle("Dialogue",payload())
check(ui:IsOpen() and opens==1 and ui.Name.Text=="Мара","server-authored speaker opens conversation")
check(ui.Role.Text=="Скупщик и поручения" and ui.Speech.Text:find("раз в день",1,true),"role and conversation copy visible")
local claim=ui.Choices:FindFirstChild("Choice_claim")
check(not claim.Active and not claim.Selectable,"unavailable reward is disabled for mouse and controller")
claim.Activated:Fire();check(#sent==1,"disabled choice cannot request payout")
ui.Choices:FindFirstChild("Choice_quests").Activated:Fire()
check(#sent==2 and sent[2][1]=="merchant_cove" and sent[2][2]=="server-session-1" and sent[2][3]=="quests",
    "only NPC/session/choice identifiers are transmitted")
ui.Choices:FindFirstChild("Choice_trade").Activated:Fire()
check(#sent==2,"pending reply suppresses a second choice")
check(not ui.Choices:FindFirstChild("Choice_trade").Active,"all choices visibly pending")
now=5;ui:Step();check(ui.Pending,"cannot immediately retry")
now=6;ui:Step();check(not ui.Pending and ui.Choices:FindFirstChild("Choice_trade").Active,"network timeout allows retry")
ui:Handle("Notice",{Text="Подойди ближе к Маре."})
check(ui.Status.Text=="Подойди ближе к Маре.","server error remains visible over modal")
ui:Handle("Dialogue",payload("server-session-2"))
check(opens==1 and ui.Session=="server-session-2","reply updates in place without reopening another HUD")
ui.Choices:FindFirstChild("Choice_trade").Activated:Fire()
check(sent[3][2]=="server-session-2" and sent[3][3]=="trade","reply replaces the request nonce")
ui:Handle("DialogueClose",{})
check(not ui:IsOpen() and closes==1 and #sent==3,"server closure does not echo a close request")
ui:Close();check(closes==1,"repeated closure is quiet")
ui:Handle("Dialogue",payload("escape-session"))
input:Fire({KeyCode=R.Enum.KeyCode.Escape},true)
check(ui:IsOpen(),"processed chat/menu input is ignored")
input:Fire({KeyCode=R.Enum.KeyCode.Escape},false)
check(not ui:IsOpen() and sent[#sent][2]=="escape-session" and sent[#sent][3]=="close","Escape closes current server conversation")
for _,screen in ipairs({{320,568},{568,320},{1280,720}}) do
    local w,h=screen[1],screen[2]
    local hostW=math.min(w*ui.Host.Size.X.Scale,620)
    local hostH=math.min(h*ui.Host.Size.Y.Scale,490)
    local x=w*ui.Host.Position.X.Scale-hostW*.5
    local y=h+ui.Host.Position.Y.Offset-hostH
    check(x>=0 and x+hostW<=w and y>=0 and y+hostH<=h,"dialogue fits screen "..w.."x"..h)
    check(hostW-32>200 and hostH-113>100,"scrolling text/choices have usable space "..w.."x"..h)
end
check(ui.Scroller.AutomaticCanvasSize==R.Enum.AutomaticSize.Y,"long conversations scroll rather than overflow phones")
check(ui.Speech.AutomaticSize==R.Enum.AutomaticSize.Y,"wrapped speech grows before choices")
check(ui.Host.Active==true,"dialogue background consumes clicks")
ui:Handle("Dialogue",payload())
ui:Destroy();check(ui.Host.Parent==nil and ui.Input==nil,"Destroy removes host and input connection")
local after=#sent
input:Fire({KeyCode=R.Enum.KeyCode.Escape},false)
check(#sent==after,"input callback is disconnected after Destroy")
print("PASS NPC dialogue UI "..checks.." server-session/input/layout checks")
