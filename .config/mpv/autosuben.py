#!/usr/bin/env python3
import os
import sys
import logging
import argparse
import json
from typing import Optional, Dict, Any

import whisper
from datetime import timedelta

class SubtitleGenerator:
    """
    A robust subtitle generation utility using OpenAI's Whisper model.
    
    Supports multiple subtitle generation configurations and error handling.
    """
    
    def __init__(self, 
                 model_size: str = "base", 
                 language: Optional[str] = None,
                 log_level: int = logging.INFO):
        """
        Initialize the subtitle generator with configurable parameters.
        
        Args:
            model_size (str): Whisper model size. Options: tiny, base, small, medium, large
            language (Optional[str]): Specify source language for improved transcription
            log_level (int): Logging verbosity level
        """
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        try:
            self.model = whisper.load_model(model_size)
            self.logger.info(f"Loaded Whisper model: {model_size}")
        except Exception as e:
            self.logger.error(f"Model loading failed: {e}")
            raise
        
        self.language = language

    def generate_subtitles(self, video_path: str) -> Dict[str, str]:
        """
        Generate subtitle file from video input.
        
        Args:
            video_path (str): Path to input video file
        
        Returns:
            Dict containing status and subtitle file path
        """
        if not os.path.exists(video_path):
            raise FileNotFoundError(f"Video file not found: {video_path}")
        
        try:
            # Advanced transcription with language specification
            transcribe_kwargs = {
                "fp16": False,  # Disable FP16 for broader compatibility
            }
            if self.language:
                transcribe_kwargs["language"] = self.language
            
            result = self.model.transcribe(video_path, **transcribe_kwargs)
            
            # Generate output paths
            base_path = os.path.splitext(video_path)[0]
            srt_path = f"{base_path}.srt"
            json_path = f"{base_path}_transcription.json"
            
            # Write SRT subtitle file
            self._write_srt(result["segments"], srt_path)
            
            # Optional: Write full transcription JSON for advanced use
            with open(json_path, "w", encoding="utf-8") as json_file:
                json.dump(result, json_file, ensure_ascii=False, indent=2)
            
            self.logger.info(f"Subtitles generated: {srt_path}")
            
            return {
                "status": "success", 
                "srt_path": srt_path,
                "json_path": json_path
            }
        
        except Exception as e:
            self.logger.error(f"Subtitle generation error: {e}")
            raise

    def _write_srt(self, segments: list, srt_path: str) -> None:
        """
        Write subtitle segments to SRT file with improved formatting.
        
        Args:
            segments (list): Transcription segments from Whisper
            srt_path (str): Output SRT file path
        """
        with open(srt_path, "w", encoding="utf-8") as srt_file:
            for i, segment in enumerate(segments, start=1):
                start = self._format_timestamp(segment["start"])
                end = self._format_timestamp(segment["end"])
                text = segment["text"].strip()
                
                # Enhanced SRT formatting with line breaks for readability
                srt_file.write(f"{i}\n{start} --> {end}\n{text}\n\n")

    @staticmethod
    def _format_timestamp(seconds: float) -> str:
        """
        Convert seconds to SRT timestamp format.
        
        Args:
            seconds (float): Time in seconds
        
        Returns:
            str: Formatted timestamp
        """
        td = timedelta(seconds=seconds)
        return str(td).replace(".", ",")[:11]

def main():
    """
    Command-line interface for subtitle generation.
    """
    parser = argparse.ArgumentParser(description="Generate subtitles using Whisper")
    parser.add_argument("video_path", help="Path to input video file")
    parser.add_argument("--model", default="base", 
                        choices=["tiny", "base", "small", "medium", "large"],
                        help="Whisper model size")
    parser.add_argument("--language", help="Specify source language")
    parser.add_argument("--log-level", default=logging.INFO, 
                        type=int, help="Logging verbosity")
    
    args = parser.parse_args()
    
    try:
        generator = SubtitleGenerator(
            model_size=args.model, 
            language=args.language,
            log_level=args.log_level
        )
        result = generator.generate_subtitles(args.video_path)
        print(json.dumps(result, indent=2))
    except Exception as e:
        error_result = {"status": "error", "message": str(e)}
        print(json.dumps(error_result, indent=2))

if __name__ == "__main__":
    main()