//
//  Test.swift
//  QUICTester
//
//  Created by Quentin De Coninck on 11/29/17.
//  Copyright © 2017 Universite Catholique de Louvain. All rights reserved.
//

import Foundation

protocol Test {
    func getDescription() -> String
    func run() -> Bool
}
