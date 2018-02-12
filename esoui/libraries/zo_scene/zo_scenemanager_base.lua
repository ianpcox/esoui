ZO_REMOTE_SCENE_NO_SCENE_IDENTIFIER = "INVALID_SCENE"

ZO_SceneManager_Base = ZO_CallbackObject:Subclass()

function ZO_SceneManager_Base:New()
    local manager = ZO_CallbackObject.New(self)
    manager:Initialize()
    return manager
end

function ZO_SceneManager_Base:Initialize()
    self.scenes = {}
    self.sceneGroups = {}
    self.callWhen = {}

    EVENT_MANAGER:RegisterForEvent("SceneManager", EVENT_FOLLOWER_SCENE_FINISHED_FRAGMENT_TRANSITION, function(eventId, ...) self:OnRemoteSceneFinishedFragmentTransition(...) end)
end

-- scenes

function ZO_SceneManager_Base:Add(scene)
    local name = scene:GetName()
    self.scenes[name] = scene
end

function ZO_SceneManager_Base:GetScene(sceneName)
    return self.scenes[sceneName]
end

-- scene groups

function ZO_SceneManager_Base:AddSceneGroup(sceneGroupName, sceneGroup)
    self.sceneGroups[sceneGroupName] = sceneGroup
end

function ZO_SceneManager_Base:GetSceneGroup(sceneGroupName)
    return self.sceneGroups[sceneGroupName]
end

function ZO_SceneManager_Base:IsSceneGroupShowing(sceneGroupName)
    local sceneGroup = self:GetSceneGroup(sceneGroupName)
    if sceneGroup then
        return sceneGroup:IsShowing()
    end

    return false
end

-- call whens

function ZO_SceneManager_Base:CallWhen(sceneName, state, func)
    local sceneCallbackList = self.callWhen[sceneName]
    if sceneCallbackList == nil then
        sceneCallbackList = {}
        self.callWhen[sceneName] = sceneCallbackList
    end

    table.insert(sceneCallbackList, {state = state, func = func})
end

function ZO_SceneManager_Base:TriggerCallWhens(sceneName, state)
    local sceneCallbackList = self.callWhen[sceneName]
    if sceneCallbackList then
        local i = 1
        while i <= #sceneCallbackList do
            local callWhenInfo = sceneCallbackList[i]
            if callWhenInfo.state == state then
                callWhenInfo.func()
                table.remove(sceneCallbackList, i)
            else
                i = i + 1
            end
        end
    end
end

-- fragments

function ZO_SceneManager_Base:AddFragment(fragment)
    if self.currentScene then
        local state = self.currentScene:GetState()
        if state == SCENE_SHOWING or state == SCENE_SHOWN then
            self.currentScene:AddTemporaryFragment(fragment)
        end
    end
end

function ZO_SceneManager_Base:RemoveFragment(fragment)
    if self.currentScene then
        local state = self.currentScene:GetState()
        if state == SCENE_SHOWING or state == SCENE_SHOWN then
            self.currentScene:RemoveTemporaryFragment(fragment)
        end
    end
end

function ZO_SceneManager_Base:AddFragmentGroup(fragmentGroup)
    for i, fragment in ipairs(fragmentGroup) do
        self:AddFragment(fragment)
    end
end

function ZO_SceneManager_Base:RemoveFragmentGroup(fragmentGroup)
    for i, fragment in ipairs(fragmentGroup) do
        self:RemoveFragment(fragment)
    end
end

-- base scene, next scene, and current scene

function ZO_SceneManager_Base:SetBaseScene(sceneName)
    self.baseScene = self.scenes[sceneName]
end

function ZO_SceneManager_Base:GetBaseScene()
    return self.baseScene
end

function ZO_SceneManager_Base:SetNextScene(nextScene, push, nextSceneClearsSceneStack, numScenesNextScenePops)
    self.nextScene = nextScene
end

function ZO_SceneManager_Base:GetNextScene()
    return self.nextScene
end

function ZO_SceneManager_Base:ClearNextScene()
    self:SetNextScene()
end

function ZO_SceneManager_Base:SetCurrentScene(currentScene)
    self.currentScene = currentScene
end

function ZO_SceneManager_Base:GetCurrentScene()
    return self.currentScene
end

function ZO_SceneManager_Base:GetCurrentSceneName()
    if self.currentScene then
        return self.currentScene:GetName()
    end

    return nil
end

function ZO_SceneManager_Base:IsCurrentSceneGamepad()
    if self.currentScene then
        return self.currentScene:WasShownInGamepadPreferredMode()
    else
        return false
    end
end

-- Scene logic

function ZO_SceneManager_Base:ShowScene(scene, sequenceNumber)
    if scene:IsRemoteScene() then
        scene:SetSequenceNumber(sequenceNumber)
    end
    scene:SetState(SCENE_SHOWING)
    scene:DetermineIfTransitionIsComplete()
end

function ZO_SceneManager_Base:HideScene(scene, sequenceNumber)
    if scene:IsRemoteScene() then
        scene:SetSequenceNumber(sequenceNumber)
    end
    scene:SetState(SCENE_HIDING)
    scene:DetermineIfTransitionIsComplete()
end

function ZO_SceneManager_Base:ShowBaseScene()
    if KEYBIND_STRIP then
        KEYBIND_STRIP:ClearKeybindGroupStateStack()
    end

    if self.baseScene then
        if not self.currentScene or (self.currentScene ~= self.baseScene and self.nextScene ~= self.baseScene) then
            self:Show(self.baseScene:GetName())
        end
    end
end

function ZO_SceneManager_Base:Toggle(sceneName)
    if self.currentScene and self.currentScene:GetName() == sceneName and self:IsShowing(sceneName) then
        self:ShowBaseScene()
    else
        self:Show(sceneName)
    end
end

function ZO_SceneManager_Base:IsShowing(sceneName)
    local currentScene = self:GetCurrentScene()
    if currentScene and currentScene:GetName() == sceneName and (currentScene:GetState() == SCENE_SHOWING or currentScene:GetState() == SCENE_SHOWN) then
        return true
    else
        return false
    end
end

function ZO_SceneManager_Base:IsShowingBaseScene()
    if self.baseScene then
        return self:IsShowing(self.baseScene:GetName())
    end
    return false
end

function ZO_SceneManager_Base:IsShowingNext(sceneName)
    if self.nextScene then
        return self.nextScene:GetName() == sceneName
    else
        return false
    end
end

function ZO_SceneManager_Base:IsShowingBaseSceneNext()
    if self.baseScene then
        return self:IsShowingNext(self.baseScene:GetName())
    end
    return false
end

function ZO_SceneManager_Base:OnNextSceneRemovedFromQueue(oldNextScene, newNextScene)
    oldNextScene:OnRemovedFromQueue()
end

function ZO_SceneManager_Base:GetPreviousSceneName()
    if self.previousScene then
        return self.previousScene:GetName()
    end

    return nil
end

function ZO_SceneManager_Base:OnSceneStateChange(scene, oldState, newState)
    if scene == self:GetCurrentScene() then
        if oldState == SCENE_HIDING and newState == SCENE_HIDDEN then
            self:OnSceneStateHidden(scene)
        elseif newState == SCENE_SHOWN then
            self:OnSceneStateShown(scene)
        end
    end
    self:TriggerCallWhens(scene:GetName(), newState)
    self:FireCallbacks("SceneStateChanged", scene, oldState, newState)
end

function ZO_SceneManager_Base:OnSceneStateHidden(scene)
    -- To be overridden
end

function ZO_SceneManager_Base:OnSceneStateShown(scene)
    local sceneGroup = scene:GetSceneGroup()
    if sceneGroup then
        sceneGroup:SetState(SCENE_GROUP_SHOWN)
    end
end

function ZO_SceneManager_Base:OnRemoteSceneFinishedFragmentTransition(sceneChangeOrigin, sceneName, sequenceNumber)
    local scene = self:GetScene(sceneName)
    if scene and scene:IsRemoteScene() and (sceneChangeOrigin ~= ZO_REMOTE_SCENE_CHANGE_ORIGIN) then
        scene:OnRemoteSceneFinishedFragmentTransition(sequenceNumber)
    end
end

function ZO_SceneManager_Base:OnPreSceneStateChange(scene, currentState, nextState)
    -- optional override
end

function ZO_SceneManager_Base:HideCurrentScene()
    if self.currentScene then
        self:Hide(self.currentScene:GetName())
    end
end

function ZO_SceneManager_Base:Push(sceneName)
    assert(false) -- This function should be overridden
end

function ZO_SceneManager_Base:SwapCurrentScene(newCurrentSceneName)
    assert(false) -- This function should be overridden
end

function ZO_SceneManager_Base:Show(sceneName)
    assert(false) -- This function should be overridden
end

function ZO_SceneManager_Base:Hide(sceneName)
    assert(false) -- This function should be overridden
end

function ZO_SceneManager_Base:RequestShowLeaderBaseScene()
    assert(false) -- This function should be overridden
end

function ZO_SceneManager_Base:SendFragmentCompleteMessage()
    assert(false) -- This function should be overridden
end

-- We don't have a scene stack in ZO_SceneManager_Base, but
-- there are still some scenes/fragments using these functions,
-- so we'll maintain these functions as shared for now
function ZO_SceneManager_Base:IsSceneOnStack(sceneName)
    return false -- Optional override
end

function ZO_SceneManager_Base:WasSceneOnStack(sceneName)
    return false -- Optional override
end

function ZO_SceneManager_Base:WasSceneOnTopOfStack(sceneName)
    return false -- Optional override
end
