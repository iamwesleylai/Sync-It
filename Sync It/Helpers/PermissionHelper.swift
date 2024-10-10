//
//  PermissionHelper.swift
//  Sync It
//
//  Created by Wesley Lai on 10/10/24.
//
import AVFoundation

struct PermissionHelper {
    static func requestCameraPermission(completion: ((Bool) -> Void)? = nil) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Camera permission granted")
                } else {
                    print("Camera permission denied")
                }
                completion?(granted)
            }
        }
    }
}
