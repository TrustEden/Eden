#!/usr/bin/env python3
"""
GPU Detection and CUDA Verification Script
Tests PyTorch CUDA availability and GPU specifications
"""

import torch
import sys

def main():
    print("=" * 60)
    print("GPU and CUDA Detection Test")
    print("=" * 60)

    # Check CUDA availability
    cuda_available = torch.cuda.is_available()
    print(f"\nCUDA Available: {cuda_available}")

    if not cuda_available:
        print("\n❌ GPU not detected!")
        print("Possible issues:")
        print("  - CUDA toolkit not installed")
        print("  - PyTorch not compiled with CUDA support")
        print("  - NVIDIA drivers not installed")
        print("  - WSL2 GPU support not configured")
        sys.exit(1)

    # CUDA version
    print(f"CUDA Version: {torch.version.cuda}")

    # GPU count
    gpu_count = torch.cuda.device_count()
    print(f"GPU Count: {gpu_count}")

    # GPU details
    print("\n" + "=" * 60)
    print("GPU Details")
    print("=" * 60)

    for i in range(gpu_count):
        print(f"\nGPU {i}:")
        print(f"  Name: {torch.cuda.get_device_name(i)}")

        props = torch.cuda.get_device_properties(i)
        print(f"  Total Memory: {props.total_memory / 1e9:.2f} GB")
        print(f"  Compute Capability: {props.major}.{props.minor}")
        print(f"  Multi-processor Count: {props.multi_processor_count}")

        # Memory info
        allocated = torch.cuda.memory_allocated(i) / 1e9
        reserved = torch.cuda.memory_reserved(i) / 1e9
        print(f"  Memory Allocated: {allocated:.2f} GB")
        print(f"  Memory Reserved: {reserved:.2f} GB")

    # Test tensor operation on GPU
    print("\n" + "=" * 60)
    print("Testing GPU Operations")
    print("=" * 60)

    try:
        # Create a test tensor and move to GPU
        test_tensor = torch.randn(1000, 1000).cuda()
        result = torch.matmul(test_tensor, test_tensor)
        print("\n✅ GPU tensor operations successful!")
        print(f"   Test tensor shape: {result.shape}")
        print(f"   Test tensor device: {result.device}")
    except Exception as e:
        print(f"\n❌ GPU operation failed: {e}")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("✅ All GPU tests passed successfully!")
    print("=" * 60)
    print("\nYour system is ready for GPU-accelerated transcription.")

if __name__ == "__main__":
    main()
