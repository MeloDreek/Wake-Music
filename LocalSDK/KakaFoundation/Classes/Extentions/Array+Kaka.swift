//
//  Array+Kaka.swift
//  KakaFoundation
//
//  Created by Melo Dreek on 2023/5/28.
//

import Foundation

extension Array {
    
    public func splitIntoChunks(ofSize size: Int) -> [[Element]] {
        var chunks: [[Element]] = []
        var chunk: [Element] = []
        
        for element in self {
            chunk.append(element)
            
            if chunk.count == size {
                chunks.append(chunk)
                chunk = []
            }
        }
        
        if !chunk.isEmpty {
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    public func safeObject(at index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

}
