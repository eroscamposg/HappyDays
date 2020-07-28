//
//  String.swift
//  HappyDays
//
//  Created by Eros Campos on 7/15/20.
//

import Foundation

class Helper {
    static func getBaseString(uniqueIdentifier: String) -> String?{
        if let index = uniqueIdentifier.range(of: "&")?.lowerBound {
            return String(uniqueIdentifier.prefix(upTo: index))
        } else {
            return nil
        }
    }
}

extension Array where Element: Equatable {
    func removingDuplicates() -> Array {
        return reduce(into: []) { result, element in
            if !result.contains(element) {
                result.append(element)
            }
        }
    }
}
