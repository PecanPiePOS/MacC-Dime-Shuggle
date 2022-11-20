//
//  Artist.swift
//  Flicker
//
//  Created by KYUBO A. SHIM on 2022/11/15.
//

import Foundation
import FirebaseFirestoreSwift
import UIKit

struct Artist {
    var state: String = "전체"
    var regions: [String]
    
    var camera: String
    var lens: String
    
    var tags: [String]
    
    var detailDescription: String
    var portfolioImageUrls: [String]
}
