window.mem0r1es = {} if not window.mem0r1es?

class window.mem0r1es.DocumentPreprocessor

  constructor : (@message, @referer, sender, sendResponse, @storageManager, @activeTab) ->
    @dontStore = false
    @screenshotDelay = 100
    @screenshotTimer = 0
    @counting = false
    @idleInterval = 5*60 #in second...
    @pageId = @message.content.pageId
    @tab = sender.tab
    @document = {}
    @document.focusTime =[]
    @document.activityTime =[]
    @currentNumberOfFetchedFeatures = 0
    @numberOfFetchedFeatures = 8
    console.log "new Document processor created to handle the mem0r1e from #{@tab.url} (#{@pageId})"
    @preprocessMem0r1e()
    sendResponse {title:"documentPreprocessorCreated", pageId:@pageId}
    @screenshotTaken = false
    chrome.idle.queryState @idleInterval, (state) =>
      @setNotIdle state is "idle"
  
  preprocessMem0r1e : () ->
    if @tab.active
      @isActive = true
      @document.focusTime.push {timestamp: new Date().getTime(), focused: @isActive}
      @takeScreenshot()
    else
      @isActive = false
    @getLanguage @tab
    @set "URL", @tab.url
    @set "referer", @referer
    @set "reverseDomainName", @tab.url.split("/")[2].split(".").reverse().join(".")
    @set "timestamp", @message.content.timestamp
    @set "pageId", @message.content.pageId
    @set "DOM", @message.content.DOMtoJSON
    lastUserStudySessionId = localStorage.getItem('lastUserStudySessionId')
    if lastUserStudySessionId?
      @set "_userStudySessionId", lastUserStudySessionId
    else
      @dontStore = true
    return
  
  getLanguage : (tab) =>
    chrome.tabs.detectLanguage tab.id, (language) =>
      @set "language", language
      return
    return
  
  set : (property, value) -> 
    @document[property] = value
    @currentNumberOfFetchedFeatures++
    if @isReadyToStore()
      @storetemporaryDocument()
    return
  
  storetemporaryDocument : (sendResponse = ()->return) ->
    if not @dontStore
      @storageManager.store "temporary", @document, sendResponse
    return
  
  isReadyToStore : () ->
    return @currentNumberOfFetchedFeatures is @numberOfFetchedFeatures
    
  takeScreenshot : () =>
    chrome.tabs.captureVisibleTab chrome.windows.WINDOW_ID_CURRENT, {quality : 80, format : "jpeg"}, (dataUrl) =>
      @storageManager.store "screenshots", {screenshotId:@pageId, _pageId:@pageId, screenshot:dataUrl}
      console.log "screenshot taken for #{@tab.url}"
      console.log dataUrl
      @screenshotTaken = true
      return
    return
    
  update : (message, sendResponse) -> #TODO Handle the sendResponse
    switch message.title
      when "mem0r1eEvent" then @createEvent(message, sendResponse)
      when "mem0r1eDSFeature" then @createDSFeature(message, sendResponse)
  
  createDSFeature : (message, sendResponse) ->
    if not @document.DSFeatures
      @document.DSFeatures = new Array()
    @document.DSFeatures.push message.content.feature
    if @isReadyToStore() and not @dontStore
      @storetemporaryDocument(sendResponse)
  
  createEvent : (message, sendResponse) ->
    if message.content.event.type is "unload"
      @sendResponse = sendResponse
    if not @dontStore
      userAction = message.content.event
      userAction._pageId = @pageId
      userAction.userActionId = "#{userAction.type}_#{new Date().getTime()}_#{Math.floor(Math.random()*100)}"
      @storageManager.store "userActions", userAction, sendResponse
      
  updateContent : (message) ->
    console.log "update content of #{@pageId}"
    return
    
  setTabActivated : (isActive) =>
    @isActive = isActive
    @document.focusTime.push {timestamp: new Date().getTime(), focused: isActive}
    @storetemporaryDocument()
    if not @screenshotTaken and isActive and not @counting
      @keepcounting()
    return
  
  keepcounting : () =>
    if @isActive and not @screenshotTaken
      if @screenshotTimer > @screenshotDelay
        @takeScreenshot()
      else
        @counting = true
        setTimeout () =>
          @screenshotTimer += 10
          @counting = false
          @keepcounting()
        ,10
 
      
    
  setNotIdle : (isIdle) ->
    @document.activityTime.push {timestamp: new Date().getTime(), active: not isIdle}
    @storetemporaryDocument()