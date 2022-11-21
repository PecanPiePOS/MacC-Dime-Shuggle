//
//  Artist.swift
//  Flicker
//
//  Created by KYUBO A. SHIM on 2022/11/15.
//

import FirebaseFirestoreSwift
import UIKit

struct Artist: Codable, Identifiable {
    @DocumentID var id: String?
    var state: String = "전체"
    var regions: [String]
    
    var camera: String
    var lens: String
    
    var tags: [String]
    
    var detailDescription: String
    var portfolioImageUrls: [String]
    
    var userInfo: [String: String]
}
