//
//  Rect.swift
//  Solar System
//
//  Created by Gaurav Sharma on 12/07/17.
//  Copyright © 2017 Godrej Innovation Center. All rights reserved.
//

import Foundation
import MetalKit
class Rect: Node
{
    
    init(nodeName: String, device: MTLDevice, nodeType: NodeType,textureImage:String,meshGenerator:ObjectMeshGenerator,textureLoader:TextureLoader,parent:Node)
    {
        
        super.init(id: nodeName, device: device, nodeType: nodeType,meshGenerator: meshGenerator,textureLoader: textureLoader,parentNode:parent,imageName: textureImage)
        
        

        
    }
}
