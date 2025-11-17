#!/usr/bin/env python3
"""
Transcription and Diarization Script
Processes audio files using faster-whisper and pyannote.audio
"""

import argparse
import json
import sys
from pathlib import Path
from datetime import datetime
import torch
from faster_whisper import WhisperModel
from pyannote.audio import Pipeline

def check_gpu():
    """Verify GPU availability and print hardware info"""
    if torch.cuda.is_available():
        gpu_name = torch.cuda.get_device_name(0)
        gpu_memory = torch.cuda.get_device_properties(0).total_memory / 1e9
        print(f"GPU: {gpu_name} ({gpu_memory:.1f}GB)", file=sys.stderr)
        return True
    else:
        print("WARNING: GPU not available, using CPU", file=sys.stderr)
        return False

def load_models(use_gpu=True):
    """Load whisper and diarization models"""
    device = "cuda" if use_gpu else "cpu"
    compute_type = "float16" if use_gpu else "int8"

    print("Loading faster-whisper model (large-v3)...", file=sys.stderr)
    whisper_model = WhisperModel(
        "large-v3",
        device=device,
        compute_type=compute_type
    )

    print("Loading pyannote diarization model...", file=sys.stderr)
    # You'll need to accept user agreement at huggingface.co/pyannote/speaker-diarization
    # and set HF_TOKEN environment variable
    diarization_pipeline = Pipeline.from_pretrained(
        "pyannote/speaker-diarization-3.1",
        use_auth_token=True
    )

    if use_gpu:
        diarization_pipeline.to(torch.device("cuda"))

    return whisper_model, diarization_pipeline

def transcribe_audio(model, audio_path):
    """Transcribe audio with word-level timestamps"""
    print("Transcribing audio...", file=sys.stderr)

    segments, info = model.transcribe(
        audio_path,
        word_timestamps=True,
        vad_filter=True,
        vad_parameters=dict(min_silence_duration_ms=500)
    )

    transcription_segments = []
    for segment in segments:
        seg_dict = {
            "start": segment.start,
            "end": segment.end,
            "text": segment.text,
            "words": []
        }

        if segment.words:
            for word in segment.words:
                seg_dict["words"].append({
                    "word": word.word,
                    "start": word.start,
                    "end": word.end
                })

        transcription_segments.append(seg_dict)

    return transcription_segments, info.duration

def diarize_audio(pipeline, audio_path):
    """Perform speaker diarization"""
    print("Performing speaker diarization...", file=sys.stderr)

    diarization = pipeline(audio_path)

    speaker_segments = []
    for turn, _, speaker in diarization.itertracks(yield_label=True):
        speaker_segments.append({
            "start": turn.start,
            "end": turn.end,
            "speaker": speaker
        })

    return speaker_segments

def merge_transcription_and_diarization(transcription_segments, speaker_segments):
    """Merge transcription segments with speaker labels"""
    print("Merging transcription with speaker labels...", file=sys.stderr)

    merged_segments = []

    for i, trans_seg in enumerate(transcription_segments):
        trans_start = trans_seg["start"]
        trans_end = trans_seg["end"]
        trans_mid = (trans_start + trans_end) / 2

        # Find the speaker segment that overlaps with this transcription segment
        speaker = "UNKNOWN"
        max_overlap = 0

        for spk_seg in speaker_segments:
            spk_start = spk_seg["start"]
            spk_end = spk_seg["end"]

            # Calculate overlap
            overlap_start = max(trans_start, spk_start)
            overlap_end = min(trans_end, spk_end)
            overlap = max(0, overlap_end - overlap_start)

            if overlap > max_overlap:
                max_overlap = overlap
                speaker = spk_seg["speaker"]

        merged_segments.append({
            "id": i,
            "start": trans_start,
            "end": trans_end,
            "speaker": speaker,
            "text": trans_seg["text"].strip(),
            "words": trans_seg["words"]
        })

    return merged_segments

def create_full_transcript(segments):
    """Create a formatted full transcript"""
    lines = []
    current_speaker = None

    for seg in segments:
        if seg["speaker"] != current_speaker:
            if current_speaker is not None:
                lines.append("")  # Add blank line between speakers
            current_speaker = seg["speaker"]
            lines.append(f"{seg['speaker']}:")

        lines.append(seg["text"])

    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Transcribe and diarize audio files")
    parser.add_argument("input", type=str, help="Input audio file path")
    parser.add_argument("--output", type=str, required=True, help="Output JSON file path")
    parser.add_argument("--no-gpu", action="store_true", help="Disable GPU acceleration")

    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"ERROR: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    # Check GPU
    use_gpu = check_gpu() and not args.no_gpu

    # Load models
    whisper_model, diarization_pipeline = load_models(use_gpu)

    # Transcribe
    transcription_segments, duration = transcribe_audio(whisper_model, str(input_path))

    # Diarize
    speaker_segments = diarize_audio(diarization_pipeline, str(input_path))

    # Merge
    merged_segments = merge_transcription_and_diarization(
        transcription_segments,
        speaker_segments
    )

    # Create full transcript
    full_transcript = create_full_transcript(merged_segments)

    # Create output JSON
    output_data = {
        "metadata": {
            "filename": input_path.name,
            "duration": duration,
            "processed_at": datetime.now().isoformat(),
            "model_transcription": "large-v3",
            "model_diarization": "pyannote/speaker-diarization-3.1",
            "gpu_used": use_gpu
        },
        "segments": merged_segments,
        "full_transcript": full_transcript
    }

    # Write output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)

    print(f"SUCCESS: Output written to {output_path}", file=sys.stderr)
    print("DONE", file=sys.stderr)

if __name__ == "__main__":
    main()
