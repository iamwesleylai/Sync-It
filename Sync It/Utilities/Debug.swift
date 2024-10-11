//
//  Debug.swift
//  Sync It
//
//  Created by Wesley Lai on 10/11/24.
//
import Foundation

struct Debug {
    static func log(_ message: String) {
        #if DEBUG
        print("DEBUG: \(message)")
        #endif
    }
}
