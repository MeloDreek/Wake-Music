//
//  CKRecordValue+Extension.swift
//  KakaFoundation
//
//  Created by Melo Dreek on 2023/6/4.
//


import CoreLocation
import CloudKit

public extension CKRecordValue {
    func asNSString() -> NSString? {
        if let stringValue = self as? String {
            return NSString(string: stringValue)
        }
        return nil
    }
    
    func asNSNumber() -> NSNumber? {
        if let intValue = self as? Int {
            return NSNumber(value: intValue)
        } else if let doubleValue = self as? Double {
            return NSNumber(value: doubleValue)
        } else if let boolValue = self as? Bool {
            return NSNumber(value: boolValue)
        }
        return nil
    }
    
    func asNSArray() -> NSArray? {
        if let arrayValue = self as? [CKRecordValue] {
            return NSArray(array: arrayValue)
        }
        return nil
    }
    
    func asNSDate() -> NSDate? {
        if let dateValue = self as? Date {
            return NSDate(timeIntervalSince1970: dateValue.timeIntervalSince1970)
        }
        return nil
    }
    
    func asNSData() -> NSData? {
        if let dataValue = self as? Data {
            return NSData(data: dataValue)
        }
        return nil
    }
    
    func asCKReference() -> CKRecord.Reference? {
        if let referenceValue = self as? CKRecord.Reference {
            return referenceValue
        }
        return nil
    }
    
    func asCKAsset() -> CKAsset? {
        if let assetValue = self as? CKAsset {
            return assetValue
        }
        return nil
    }
    
    func asCLLocation() -> CLLocation? {
        if let locationValue = self as? CLLocation {
            return locationValue
        }
        return nil
    }
}

