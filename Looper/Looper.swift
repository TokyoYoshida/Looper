//
//  Looper.swift
//  Looper
//
//  Created by 冨田 直希 on 2016/04/10.
//  Copyright © 2016年 冨田 直希. All rights reserved.
//

import Foundation
import AVFoundation

let kOutputBus: UInt32 = 0;
let kInputBus: UInt32 = 1;

class Looper {
  class RefConData {
    var audioUnit: AudioUnit? = nil;
    var loopDatas: LoopSounds = LoopSounds();
    var currentLoop: LoopSound?;
    var index: Int = 0;
  }

  var refData: RefConData;
  var processing = false;

  init() {
    refData = RefConData();
  }

  // MARK: -
  // MARK: Initializers

  func initialize() {
    initializeAudioUnit();
  }

  /**
   * AudioUnitを初期化します
   */
  func initializeAudioUnit() {
    var acd = AudioComponentDescription();
    acd.componentType         = kAudioUnitType_Output;
    acd.componentSubType      = kAudioUnitSubType_RemoteIO;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags        = 0;
    acd.componentFlagsMask    = 0;

    guard let ac = AudioComponentFindNext(nil, &acd) else { return  };
    AudioComponentInstanceNew( ac, &( refData.audioUnit ) );

    initializeCallbacks();
    initializeEnableIO();
    initializeAudioFormat();
    initializeAudioUnitSetting();

    AudioUnitInitialize( refData.audioUnit! );
  }


  /**
   * 入力、出力のコールバックを設定します
   */
  func initializeCallbacks() {
    var inputCallback = AURenderCallbackStruct( inputProc: RecordingCallback, inputProcRefCon: Unmanaged<Looper.RefConData>.passRetained(refData).toOpaque() );
    var outputCallback = AURenderCallbackStruct( inputProc: RenderCallback, inputProcRefCon: Unmanaged<Looper.RefConData>.passRetained(refData).toOpaque() );

    AudioUnitSetProperty( refData.audioUnit!,
                          kAudioOutputUnitProperty_SetInputCallback,
                          kAudioUnitScope_Global,
                          kInputBus,
                          &inputCallback,
                          UInt32(MemoryLayout<AURenderCallbackStruct>.size ) );

    AudioUnitSetProperty( refData.audioUnit!,
                          kAudioUnitProperty_SetRenderCallback,
                          kAudioUnitScope_Global,
                          kOutputBus,
                          &outputCallback,
                          UInt32(MemoryLayout<AURenderCallbackStruct>.size ) );
  }

  /**
   * 入力、出力を有効化します
   */
  func initializeEnableIO() {
    var flag: UInt32 = 1;
    AudioUnitSetProperty( refData.audioUnit!,
                          kAudioOutputUnitProperty_EnableIO,
                          kAudioUnitScope_Input,
                          kInputBus,
                          &flag,
                          UInt32( MemoryLayout<UInt32>.size ) );

    AudioUnitSetProperty( refData.audioUnit!,
                          kAudioOutputUnitProperty_EnableIO,
                          kAudioUnitScope_Output,
                          kOutputBus,
                          &flag,
                          UInt32( MemoryLayout<UInt32>.size ) );
  }

  /**
   * 音声の形式を設定します
   * 入力、出力はどちらも同じ形式になります
   */
  func initializeAudioFormat() {
    var audioFormat: AudioStreamBasicDescription = AudioStreamBasicDescription();
    audioFormat.mSampleRate			  = 44100.00;
    audioFormat.mFormatID			    = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags		  = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket	= 1;
    audioFormat.mChannelsPerFrame	= 1;
    audioFormat.mBitsPerChannel		= 16;
    audioFormat.mBytesPerPacket		= 2;
    audioFormat.mBytesPerFrame		= 2;

    AudioUnitSetProperty( refData.audioUnit!,
                          kAudioUnitProperty_StreamFormat,
                          kAudioUnitScope_Output,
                          kInputBus,
                          &audioFormat,
                          UInt32( MemoryLayout<AudioStreamBasicDescription>.size ) );

    AudioUnitSetProperty( refData.audioUnit!,
                          kAudioUnitProperty_StreamFormat,
                          kAudioUnitScope_Input,
                          kOutputBus,
                          &audioFormat,
                          UInt32( MemoryLayout<AudioStreamBasicDescription>.size ));
  }

  /**
   * AudioUnitのその他の設定を行います
   */
  func initializeAudioUnitSetting() {
    var flag = 0;
    AudioUnitSetProperty( refData.audioUnit!,
                          kAudioUnitProperty_ShouldAllocateBuffer,
                          kAudioUnitScope_Output,
                          kInputBus,
                          &flag,
                          UInt32( MemoryLayout<UInt32>.size ) );
  }

  // MARK: -
  // MARK: Public methods

  func begin() {
    restart();
  }

  func end() {
    stop();
  }

  func reset() {

  }

  func restart() {
    if( processing ) {
      return;
    }
    print( "start" );
    refData.currentLoop = LoopSound();
    processing = true;
    AudioOutputUnitStart( refData.audioUnit! );
  }

  func stop() {
    if( !processing ) {
      return;
    }

    print( "end" );
    AudioOutputUnitStop( refData.audioUnit! );
    refData.loopDatas.add( element: refData.currentLoop! );
    refData.currentLoop = nil;
    refData.index = 0;
    processing = false;
  }
}

// MARK: -
// MARK: Callback methods

/**
 * 音声入力コールバックです
 */
func RecordingCallback( inRefCon: UnsafeMutableRawPointer,
                     ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                     inTimeStamp: UnsafePointer<AudioTimeStamp>,
                     inBusNumber: UInt32,
                     inNumberFrames: UInt32,
                     ioData: UnsafeMutablePointer<AudioBufferList>?) -> (OSStatus)
{
    let refData = unsafeBitCast( inRefCon, to: Looper.RefConData.self)
  // バッファ確保
  // バッファサイズ計算。Channel * Frame * sizeof( Int16 )
    let dataSize = UInt32( 1 * inNumberFrames * UInt32( MemoryLayout<Int16>.size ) );
  let dataMem = malloc( Int( dataSize ) );
  let audioBuffer = AudioBuffer.init( mNumberChannels: 1, mDataByteSize: dataSize, mData: dataMem );
  var audioBufferList = AudioBufferList.init( mNumberBuffers: 1, mBuffers: audioBuffer );

  // AudioUnitRender呼び出し
  AudioUnitRender( refData.audioUnit!,
                   ioActionFlags,
                   inTimeStamp,
                   inBusNumber,
                   inNumberFrames,
                   &audioBufferList );

  // もらってきたバッファをLoopSoundsにadd
  let ubpBuf = UnsafeBufferPointer<Int16>( audioBufferList.mBuffers );
    refData.currentLoop!.add( buffer: Array( ubpBuf ) );
  free(dataMem)

  return noErr;
}

/**
 * 音声出力コールバックです
 */

func RenderCallback( inRefCon: UnsafeMutableRawPointer,
                     ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                     inTimeStamp: UnsafePointer<AudioTimeStamp>,
                     inBusNumber: UInt32,
                     inNumberFrames: UInt32,
                     ioData: UnsafeMutablePointer<AudioBufferList>?) -> (OSStatus)
{
    let refData = unsafeBitCast( inRefCon, to: Looper.RefConData.self)
  // LoopSoundsから再生する範囲のAudioBufferを取得
  let end = ( refData.currentLoop?.buffers.count )! % Int( refData.loopDatas.loopCount() );
    let start = end - Int( inNumberFrames ) >= 0 ? end - Int( inNumberFrames ) : 0

    let arr = refData.loopDatas.get( beginIndex: start, endIndex: end );

  // ioDataのバッファにコピー
    let buf = UnsafeMutableBufferPointer<Int16>( (ioData?.pointee.mBuffers)! );
  for i in 0 ..< arr.count {
    buf[ i ] = arr[ i ];
  }

  return noErr;
}

class LoopSound {
  var buffers: [ Int16 ] = [];

  func add( buffer: [ Int16 ] ) {
    buffers += buffer;
  }

  func get( index: Int ) -> Int16 {
    return buffers[ index ];
  }

  func get( beginIndex: Int, endIndex:Int ) -> [ Int16 ] {
    return Array( buffers[ beginIndex..<endIndex ] );
  }
}

class LoopSounds {
  var elements: [ LoopSound ] = [];

  func add( element: LoopSound ) {
    elements.append( element );
  }

  func get( index: Int ) {

  }

  func loopCount() -> Int32 {
    if( elements.count == 0 ) {
      return Int32( 80000 );
    } else {
      return Int32( elements[ 0 ].buffers.count );
    }
  }

  func get( beginIndex: Int, endIndex:Int ) -> [ Int16 ] {
    var result: [ Int16 ] = [];
    var sum: Int16 = 0;
    for i in beginIndex ..< endIndex {
      sum = 0;
      for element in elements {
        sum += Int16( Int16( element.get( index: i ) / Int16( elements.count ) ) );
      }
      result.append( sum );
    }
    return result;
  }
}
