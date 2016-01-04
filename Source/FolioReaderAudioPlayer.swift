//
//  FolioReaderAudioPlayer.swift
//  Pods
//
//  Created by Kevin Jantzer on 1/4/16.
//
//

import UIKit
import AVFoundation


class FolioReaderAudioPlayer: NSObject, AVAudioPlayerDelegate {

    var player: AVAudioPlayer!
    var currentHref: String!
    var currentFragment: String!
    var currentAudioFile: String!
    var currentBeginTime: Double!
    var currentEndTime: Double!
    var playingTimer: NSTimer!

    var tempTimer: NSTimer!

    func stop() {

        if( player != nil && player.playing ){
            player.stop()
        }

        // temp code, but `stop` will likely be a method
        if( tempTimer != nil ){
            tempTimer.invalidate()
            tempTimer = nil
        }
    }

    func pause() {
        if( player != nil && player.playing ){
            player.pause()
        }
    }

    func playAudio(href: String, fragmentID: String) {

        stop();

        currentHref = href
        currentFragment = currentHref+"#"+fragmentID

        let smilFile = book.smilFileForHref(href)
        let smil =  smilFile.parallelAudioForFragment(currentFragment)

        if( smil != nil ){
            playFragment(smil)
            startPlayerTimer()
        }

    }

    func startPlayerTimer() {
        playingTimer = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: "playerTimerObserver", userInfo: nil, repeats: true)
    }

    func stopPlayerTimer() {
        if( playingTimer != nil ){
            playingTimer.invalidate()
            playingTimer = nil
        }
    }

    func playerTimerObserver(){
        if( currentEndTime != nil && currentEndTime > 0 && player.currentTime > currentEndTime ){
            playFragment(nextAudioFragment())
        }
    }

    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        playFragment(nextAudioFragment())
    }

    func playFragment(smil: FRSmil!){

        if( smil == nil ){
            print("no more parallel audio to play")
            stop()
            return
        }

        let textFragment = smil.textElement().attributes["src"]
        let audioFile = smil.audioElement().attributes["src"]

        currentBeginTime = smil.clipBegin()
        currentEndTime = smil.clipEnd()

//        print(currentBeginTime)
//        print(currentEndTime)

        // new audio file to play, create the audio player
        if( player == nil || (audioFile != nil && audioFile != currentAudioFile) ){

//            print("play file: "+audioFile!)
            currentAudioFile = audioFile

            let fileURL = book.smils.basePath.stringByAppendingString("/"+audioFile!)
            let audioData = NSData(contentsOfFile: fileURL)

            if( audioData != nil ){
                player = try! AVAudioPlayer(data: audioData!)
                player.prepareToPlay()
                player.delegate = self

            }else{
                print("could not read audio file")
            }
        }

        if( player != nil ){

            if( player.currentTime < currentBeginTime || ( currentEndTime > 0 && player.currentTime > currentEndTime) ){
                player.currentTime = currentBeginTime;
            }

            player.play();

            //print("mark fragment: "+textFragment!)

            let textParts = textFragment!.componentsSeparatedByString("#")
            let fragmentID = textParts[1];

            FolioReader.sharedInstance.readerCenter.audioMark(href: currentHref, fragmentID: fragmentID)
        }

    }


    func nextAudioFragment() -> FRSmil! {

        let smilFile = book.smilFileForHref(currentHref)
        let smil = currentFragment == nil ? smilFile.parallelAudioForFragment(nil) : smilFile.nextParallelAudioForFragment(currentFragment)

        if( smil != nil ){
            currentFragment = smil.textElement().attributes["src"]
            return smil
        }

        currentHref = book.spine.nextChapter(currentHref)!.href
        currentFragment = nil

        if( currentHref == nil ){
            return nil
        }

        return nextAudioFragment()
    }


}