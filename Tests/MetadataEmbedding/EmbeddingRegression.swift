@main struct Tests {
    static var count=0
    static func check(_ good: @autoclosure ()->Bool, _ message:String) { count += 1; if !good() { fatalError(message) } }
    static func reset() { TaglibMetadataParser.disk=MetadataTagModel();TaglibMetadataParser.writes=[];TaglibMetadataParser.fail=nil;TaglibMetadataParser.afterWrite=nil;SandboxFileManager.shared.covers=[];ImageDownloader.hook=nil;ImageDownloader.delay=0;AudioFingerprintMatcher.result=nil;AudioFingerprintMatcher.callback=nil }
    static func wait(_ operation: Operation) async { for _ in 0..<100 { if operation.isFinished {return}; try? await Task.sleep(nanoseconds:10_000_000) }; fatalError("operation never finished") }
    static func main() async {
        let editor=MusicTagEditor.shared
        var model=MusicItemModel()
        var tags=AudioFingerprintModel(); tags.title=" New title ";tags.artist="New artist";tags.album="New album";tags.genres="New genre";tags.year=2026;tags.trackNumber=8;tags.coverArt="https://example.invalid/art.png";tags.lyrics=[LyricInfoModel(text:"new lyric")]
        reset()
        let d=TaglibMetadataParser.disk!;d.title="Disk title";d.artist="Disk artist";d.album="Disk album";d.genre="Disk genre";d.year=1999;d.track=3;d.comment="Keep comment";d.coverArt=UIImage("old");d.coverArtData=Data([1]);d.lyricModel=LyricLineModel("old lyric")
        var result=await editor.embeddedAllMetadata(model:model,tagsModel:tags,config:AutoEditConfig())
        check(TaglibMetadataParser.writes.isEmpty,"stale model overwrote disk tags")
        check(result.updatedModel.title=="Disk title","returned stale title")
        check(result.updatedModel.comment=="Keep comment","comment not preserved")
        check(result.updatedModel.coverArt?.id=="old","existing cover not returned")
        check(result.updatedModel.lyricModel?.text=="old lyric","existing lyric not returned")

        result=await editor.embeddedAllMetadata(model:model,tagsModel:tags,config:AutoEditConfig(fillMode:.forceOverwrite))
        check(TaglibMetadataParser.writes.count==8,"explicit acoustic overwrite ignored")
        check(result.updatedModel.title=="New title","overwrite returned stale title")
        check(result.updatedModel.comment=="Keep comment","force overwrite touched comment")

        reset();model.title="Stale cached title";model.coverArt=UIImage("cached");model.lyricModel=LyricInfoModel(text:"cached lyric")
        result=await editor.embeddedAllMetadata(model:model,tagsModel:tags,config:AutoEditConfig())
        check(TaglibMetadataParser.writes.count==8,"missing on-disk tags were not filled")
        check(result.updatedModel.title=="New title","candidate trimming failed")
        check(result.updatedModel.lyricModel?.text=="new lyric","new lyrics missing")
        check(SandboxFileManager.shared.covers==["download"],"persisted artwork not cached")
        check(result.updatedModel.comment==nil,"branding comment inserted")

        reset();var blank=AudioFingerprintModel();blank.title=" \n ";blank.artist="";blank.album="\t";blank.genres=" ";blank.year=Int.max;blank.trackNumber=Int.max
        result=await editor.embeddedAllMetadata(model:model,tagsModel:blank,config:AutoEditConfig(fillMode:.forceOverwrite))
        check(TaglibMetadataParser.writes.isEmpty,"blank or overflow values written")
        check(result.errorTags==[.year,.trackNumber],"overflow did not report failures")

        reset();TaglibMetadataParser.disk?.title="disk";var catalog=tags;catalog.metadataSource="appleCatalog"
        result=await editor.embeddedAllMetadata(model:model,tagsModel:catalog,config:AutoEditConfig(fillMode:.forceOverwrite,isSetInstrumental:true))
        check(TaglibMetadataParser.disk?.title=="disk","catalog overwrote established title")
        check(!TaglibMetadataParser.writes.contains(.title),"catalog force was honored")
        reset();catalog=AudioFingerprintModel();catalog.metadataSource="appleCatalogArtwork";catalog.coverArt=tags.coverArt
        _=await editor.embeddedAllMetadata(model:model,tagsModel:catalog,config:AutoEditConfig(fillMode:.forceOverwrite,isSetInstrumental:true))
        check(TaglibMetadataParser.writes==[.artWork],"catalog artwork synthesized tags/instrumental")

        reset();ImageDownloader.hook={TaglibMetadataParser.disk?.coverArt=UIImage("arrived");TaglibMetadataParser.disk?.coverArtData=Data([2]);TaglibMetadataParser.disk?.lyricModel=LyricLineModel("arrived lyric")}
        result=await editor.embeddedAllMetadata(model:model,tagsModel:tags,config:AutoEditConfig())
        check(!TaglibMetadataParser.writes.contains(.artWork),"download race overwrote new disk cover")
        check(!TaglibMetadataParser.writes.contains(.lyrics),"download race overwrote new disk lyrics")
        check(result.updatedModel.coverArt?.id=="arrived","post-download snapshot missing")

        reset();TaglibMetadataParser.disk=nil
        result=await editor.embeddedAllMetadata(model:model,tagsModel:tags,config:AutoEditConfig())
        check(TaglibMetadataParser.writes.isEmpty,"unreadable disk mutated")
        check(result.errorTags != nil,"unreadable disk reported success")
        reset();TaglibMetadataParser.fail = .title
        result=await editor.embeddedAllMetadata(model:model,tagsModel:tags,config:AutoEditConfig())
        check(result.updatedModel.title==nil,"failed save returned recognition title")
        check(result.errorTags==[.title],"save failure not reported")

        reset();TaglibMetadataParser.disk?.lyricModel=LyricLineModel("keep")
        _=await editor.embeddedAllMetadata(model:model,tagsModel:AudioFingerprintModel(),config:AutoEditConfig(fillMode:.forceOverwrite,isSetInstrumental:true))
        check(TaglibMetadataParser.writes.isEmpty,"instrumental replaced disk lyric")
        reset()
        _=await editor.embeddedAllMetadata(model:model,tagsModel:AudioFingerprintModel(),config:AutoEditConfig(isSetInstrumental:true))
        check(TaglibMetadataParser.writes==[.lyrics],"explicit absent-lyric instrumental not honored")

        reset()
        _=await editor.embeddedAllMetadata(model:model,tagsModel:tags,config:AutoEditConfig(),isCancelled:{true})
        check(TaglibMetadataParser.writes.isEmpty,"pre-cancelled helper wrote")
        reset();ImageDownloader.delay=100_000_000
        let embedding=Task { await editor.embeddedAllMetadata(model:model,tagsModel:tags,config:AutoEditConfig()) }
        try? await Task.sleep(nanoseconds:20_000_000);embedding.cancel();_=await embedding.value
        check(TaglibMetadataParser.writes.isEmpty,"cancelled download wrote")

        reset();let stopping=LockedCounter();var partial=AudioFingerprintModel();partial.title="Saved before cancellation";partial.artist="Must not write"
        TaglibMetadataParser.afterWrite={stopping.increment()}
        result=await editor.embeddedAllMetadata(model:model,tagsModel:partial,config:AutoEditConfig(),isCancelled:{stopping.value>0})
        check(TaglibMetadataParser.writes==[.title],"cancellation during commit did not stop later fields")
        check(result.updatedModel.title=="Saved before cancellation","partial cancellation lost persisted state")
        check(result.updatedModel.artist==nil,"partial cancellation returned unwritten artist")

        reset();var completions=0;let queue=OperationQueue();queue.isSuspended=true
        let queued=MusicTagEditorOperation(model:model,config:AutoEditConfig()){_,_ in completions += 1}
        queue.addOperation(queued);queued.cancel();queue.isSuspended=false;await wait(queued)
        check(completions==1,"queued cancellation completion not exactly once")
        queued.cancel();check(completions==1,"duplicate cancellation completion")
        let preCancelled=MusicTagEditorOperation(model:model,config:AutoEditConfig()){_,_ in completions += 1}
        preCancelled.cancel();queue.addOperation(preCancelled);await wait(preCancelled)
        check(completions==2,"pre-enqueue cancellation completion missing")

        reset();var cancelCompletions=0
        let running=MusicTagEditorOperation(model:model,config:AutoEditConfig()){_,_ in cancelCompletions += 1}
        queue.addOperation(running)
        for _ in 0..<100 { if AudioFingerprintMatcher.callback != nil { break }; try? await Task.sleep(nanoseconds:1_000_000) }
        let lateCallback=AudioFingerprintMatcher.callback
        running.cancel();await wait(running);lateCallback?(.success(tags))
        try? await Task.sleep(nanoseconds:20_000_000)
        check(cancelCompletions==1,"late network callback completed twice")
        check(TaglibMetadataParser.writes.isEmpty,"late callback wrote after cancellation")

        reset();AudioFingerprintMatcher.result = .failure(.custom("not matched"));TaglibMetadataParser.disk?.lyricModel=LyricLineModel("existing")
        let failed=MusicTagEditorOperation(model:model,config:AutoEditConfig(isSetInstrumental:true)){_,_ in}
        queue.addOperation(failed);await wait(failed)
        check(TaglibMetadataParser.writes.isEmpty,"recognition failure clobbered existing lyrics/comment")

        reset();queue.isSuspended=true;let cancelledCount=LockedCounter()
        let cancelledOperations=(0..<64).map { _ in MusicTagEditorOperation(model:model,config:AutoEditConfig()){_,_ in cancelledCount.increment()} }
        cancelledOperations.forEach { queue.addOperation($0) }
        cancelledOperations.forEach{$0.cancel()};queue.isSuspended=false
        for operation in cancelledOperations { await wait(operation) }
        check(cancelledCount.value==64,"cancelled batch did not drain every completion")
        check(cancelledOperations.allSatisfy{$0.isFinished && !$0.isExecuting},"cancelled batch has inconsistent operation state")

        reset();var renameModel=model
        let source=URL(fileURLWithPath:ProcessInfo.processInfo.environment["EMBEDDING_TEST_DIR"]!).appendingPathComponent("rename-fixture.mp3")
        try! Data("disposable non-audio rename fixture".utf8).write(to:source)
        renameModel.mediaPlayURL=source;var renameTags=AudioFingerprintModel();renameTags.title="Persisted name"
        result=await editor.embeddedAllMetadata(model:renameModel,tagsModel:renameTags,config:AutoEditConfig(fileName:.title))
        check(result.updatedModel.mediaPlayURL.lastPathComponent=="Persisted name.mp3","rename did not use persisted title")
        check(!FileManager.default.fileExists(atPath:source.path),"rename left original path")
        check(FileManager.default.fileExists(atPath:result.updatedModel.mediaPlayURL.path),"renamed file missing")
        check(AppLocalManager.shared.moves==1,"bookmark/path update did not finish before completion")
        print("PASS \(count) safe embedding/operation checks using production source and in-memory tag I/O")
    }
}
