//
//  Planet.swift
//  Solar System
//
//  Created by Gaurav Sharma on 07/06/17.
//  Copyright © 2017 Godrej Innovation Center. All rights reserved.
//

import Foundation
import simd
import MetalKit

class Planet:Node
{
    
    let no_of_days_to_be_revolved:Int
    let rotate_period:Float32
    var animate:Bool
    
    init(name:String,textureImage:String,type:NodeType, device:MTLDevice,meshGenerator:ObjectMeshGenerator,textureLoader:TextureLoader,parent:Node)
    {
        
        switch name {
        case "Mercury":
            no_of_days_to_be_revolved = 88
            rotate_period = 58
            break
        case "Venus":
            no_of_days_to_be_revolved = 225
            rotate_period = -243
            break
        case "Earth":
            no_of_days_to_be_revolved = 365
            rotate_period = 1
            break
        case "Mars":
            no_of_days_to_be_revolved = 687
            rotate_period = 1
            break
        case "Jupiter":
            no_of_days_to_be_revolved = 43332
            rotate_period = 0.5
            break
        case "Sun":
            no_of_days_to_be_revolved = 35
            rotate_period = 35
        default:
            no_of_days_to_be_revolved = 1
            rotate_period = 1
            print("Invalid name of planet")
            break
        }
        
        animate = false
        super.init(id:name,device: device,nodeType: type,meshGenerator:meshGenerator,textureLoader: textureLoader,parentNode:parent,imageName: textureImage)
       
        
        
      
        
    }
    
    
    

   
}
