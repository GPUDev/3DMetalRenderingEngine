
/*In This application,we are using right handed world coordinate system.that means +ve z axis is towards us and negative
 z axis is going through screen*/

import MetalKit

class  Renderer: NSViewController,MTKViewDelegate {
    
    var commandQueue:MTLCommandQueue! = nil
    var defaultLibrary:MTLLibrary!
    private var renderPipeline: MTLRenderPipelineState! = nil
    private var mainRenderPipeline:MTLRenderPipelineState! = nil
    private var sampler:MTLSamplerState!
    private var depthStencilState:MTLDepthStencilState!
    private var textureLoader:TextureLoader!
    private var camera:Camera!
    var cameraUniformBuffer:MTLBuffer!
    var nodeTransformPerBufferIndex:Int = 0 //choosing one out of three uniformPerNodeBuffers so that we can pass correct transform of all node in a frame to GPU
    var texturePerInstanceArrayIndex:Int = 0
    private let inflightSemaphore = DispatchSemaphore(value:3)
    private var device:MTLDevice!
    private var frame_count:Int32 = 0
    private var lastFrameTime:Float32 = 0.0
    private var nodeTree:Node!
    private var nodeCountInTree:Int = 0
    private var millisecondFactor:Double = 0.0
    var nodeMessList = [NodeType:NodeMess]()
    private var renderPassDescriptor:MTLRenderPassDescriptor = MTLRenderPassDescriptor()
    private var mainPassFrameBuffer:MTLTexture!
    private var mainPassDepthBuffer:MTLTexture!
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        var timebase:mach_timebase_info_data_t = mach_timebase_info_data_t()
        
        /*this will fill timebase object with a number and denominator*/
        mach_timebase_info(&timebase)
        
        millisecondFactor = Double(timebase.numer)/Double(timebase.denom) * 1e-6/*.000001*/
        
        
        //let devices = MTLCopyAllDevices()
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("metal can't be inialized")
            exit(0)
        }
        
        /*for device in devices
        {
            if(device.isLowPower)
            {
                self.device = device
                //break
            }
        }*/
        print("GPU name:\(device.name)")
        self.device = device
        let view  = self.view as!MTKView
        view.delegate = self
        view.device = device
        view.sampleCount = 4
        setUpMetalPipeline()
        camera = Camera()
        let messGenerator = ObjectMeshGenerator()
        textureLoader = TextureLoader(device: device)
        camera.viewingWidth = Float32((view.window?.frame.width)!)
        camera.viewingHeight = Float32((view.window?.frame.height)!)
        let renderView = RenderView(camera:camera,frame: view.frame,renderer:self)
        self.view.addSubview(renderView)//it is needed because this is the object on which mouseDown,mouseMove or keyDown function will be called by Window object
        //setting window delegate to window object
        view.window?.delegate = renderView
        
        /*creating three types of NodeMess objects to store data of same type of instance in same type of node mess*/
        /*var mess = NodeMess(type: .GRE_PLANET)
        nodeMessList[.Planet] = mess
        mess = NodeMess(type: .GRE_CUBE)
        nodeMessList[.Cube] = mess
        mess = NodeMess(type: .GRE_RECT)
        nodeMessList[.Rect] = mess
        
        nodeTree = renderView.createNodeTree(id: "Solar System", device: device, meshGenerator: messGenerator, textureLoader: textureLoader)*/
        /*creating NodeMess object of mess type Node for which we need not to generate mess because such type of nodes
         are loaded in memory from data exchange files like .obj,.stl,.asm,.iges,*/
        let mess = NodeMess(type: .GRE_MESS)
        nodeMessList[.GRE_MESS] = mess
        /*this method will create node tree from specified .obj file*/
        //nodeTree = renderView.createNodeTree(obj_file_path: "/Applications/MetalAPIsCode/ModelLoader/ModelLoaderLib/Resources/model2/scene1.obj", device: device, textureLoader: textureLoader,mess_gen: messGenerator)
        nodeTree = renderView.createNodeTree(obj_file_path: "/Applications/MetalAPIsCode/ModelLoader/ModelLoaderLib/Resources/model/pose2.obj", device: device, textureLoader: textureLoader,mess_gen: messGenerator)
        //nodeTree = renderView.createNodeTree(obj_file_path: "/Applications/MetalAPIsCode/ModelLoader/ModelLoaderLib/Resources/Sample.obj", device: device, textureLoader: textureLoader,mess_gen: messGenerator)
        
        cameraUniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: [])
       
    
        
    }
    private func setUpMetalPipeline()
    {
        
        
        commandQueue = device?.makeCommandQueue()
        
        let samplerStateDescrip = MTLSamplerDescriptor()
        samplerStateDescrip.minFilter = MTLSamplerMinMagFilter.linear
        samplerStateDescrip.magFilter = MTLSamplerMinMagFilter.linear
        samplerStateDescrip.mipFilter = MTLSamplerMipFilter.linear
        samplerStateDescrip.sAddressMode = MTLSamplerAddressMode.clampToEdge
        samplerStateDescrip.tAddressMode = .clampToEdge
        samplerStateDescrip.rAddressMode = .clampToEdge
        samplerStateDescrip.normalizedCoordinates = true
        samplerStateDescrip.lodMinClamp = 0
        samplerStateDescrip.lodMaxClamp = Float.greatestFiniteMagnitude
        sampler = device?.makeSamplerState(descriptor: samplerStateDescrip)
        
        //metal library creation
        defaultLibrary = device?.makeDefaultLibrary()
        let vert_func = defaultLibrary?.makeFunction(name: "vertexShader" )
        let frag_func = defaultLibrary?.makeFunction(name: "fragmentShader")
        let visualize_vert_func = defaultLibrary.makeFunction(name: "visualizeVertexShader")
        let visualize_frag_func = defaultLibrary.makeFunction(name: "visualizeFragmentShader")
        let vertexDescriptor = MTLVertexDescriptor()
        //vertex descriptor creation
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float32>.size * 4
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.attributes[2].format = .float4
        vertexDescriptor.attributes[2].offset = 8 * MemoryLayout<Float32>.size
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        //renderstatepipline creation
        let renderPipelineDesc = MTLRenderPipelineDescriptor()
        renderPipelineDesc.colorAttachments[0].pixelFormat = (self.view as!MTKView).colorPixelFormat
        //renderPipelineDesc.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDesc.sampleCount = 4//(self.view as!MTKView).sampleCount
        renderPipelineDesc.vertexFunction = vert_func
        renderPipelineDesc.fragmentFunction = frag_func
        renderPipelineDesc.vertexDescriptor = vertexDescriptor
        do
        {
        try renderPipeline = device?.makeRenderPipelineState(descriptor: renderPipelineDesc)
        
        }
        catch _
        {
         print("Unable to create render pipeline state")
        }
        
        let renderPipelineDesc1 = MTLRenderPipelineDescriptor()
        renderPipelineDesc1.colorAttachments[0].pixelFormat = (self.view as!MTKView).colorPixelFormat
        renderPipelineDesc1.vertexFunction = visualize_vert_func
        renderPipelineDesc1.sampleCount = (self.view as!MTKView).sampleCount
        renderPipelineDesc1.fragmentFunction = visualize_frag_func
        renderPipelineDesc1.sampleCount = (self.view as!MTKView).sampleCount
        
        do
        {
            try mainRenderPipeline = device.makeRenderPipelineState(descriptor: renderPipelineDesc1)
        }
        catch _
        {
            print("Unable to create render pipeline state")
        }
        
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0,green: 0.0,blue: 0.0,alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .dontCare
        
        let view = self.view as!MTKView
        let textDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(view.frame.width)
            , height: Int(view.frame.height), mipmapped: false)
        textDesc.depth = 1
        textDesc.usage = [MTLTextureUsage.renderTarget,MTLTextureUsage.shaderRead]
        textDesc.storageMode = .private
        mainPassFrameBuffer = device.makeTexture(descriptor: textDesc)
        renderPassDescriptor.colorAttachments[0].texture = mainPassFrameBuffer
        
        
        let depthTexDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(view.frame.width), height: Int(view.frame.height), mipmapped: false)
        depthTexDesc.usage = [MTLTextureUsage.renderTarget,MTLTextureUsage.shaderRead]
        depthTexDesc.storageMode = .private
        mainPassDepthBuffer = device.makeTexture(descriptor: depthTexDesc)
        renderPassDescriptor.depthAttachment.texture = mainPassDepthBuffer
        
    }
    /*this is the function will be called in each frame*/
    func updateBuffers()
    {
        
        for messTypePair in nodeMessList
        {
            let mess = messTypePair.value
            if(!(mess.nodeTransformArray.isEmpty))
            {
              mess.nodeTransformArray.removeAll()
            }
            if(!(mess.textureImagesArray.isEmpty))
            {
                mess.textureImagesArray.removeAll()
            }
            
            mess.instance_count = 0
        }
        
        nodeTree.updateNodesMess(nodeMessList: nodeMessList)
        
       
        for nodeMess in nodeMessList
        {
            let messObject = nodeMess.value
        
        /*if number of instances are changed then we have to allocate nodeTransformPerInstanceBuffer again*/
        if(messObject.instance_count != messObject.prev_instance_count)
        {
            if(!messObject.nodeTransformPerInstanceBuffer.isEmpty)
            {
                messObject.nodeTransformPerInstanceBuffer.removeAll()
            }
            if(!(messObject.texturePerInstanceArray.isEmpty))
            {
               
                messObject.texturePerInstanceArray.removeAll()
                

            }
            
            let texture = textureLoader.getTextureWithSlices(imageArray: messObject.textureImagesArray)
            messObject.texturePerInstanceArray[texturePerInstanceArrayIndex] = texture
            
            for i in 0..<3
            {
                
                let nodeTransformsBuffer = device.makeBuffer(length: MemoryLayout<matrix_float4x4>.stride * Int(messObject.instance_count) , options: .storageModeShared)
                nodeTransformsBuffer?.label = "uniform buffer\(i) "
                messObject.nodeTransformPerInstanceBuffer[i] = nodeTransformsBuffer
                
            }
        
            messObject.prev_instance_count = messObject.instance_count
        }
        
        let nodeTransformBufferPointer = messObject.nodeTransformPerInstanceBuffer[nodeTransformPerBufferIndex]?.contents()
        memcpy(nodeTransformBufferPointer, messObject.nodeTransformArray,MemoryLayout<matrix_float4x4>.stride * Int(messObject.instance_count))
            
        }
        
        let cameraUniformBufferPointer = cameraUniformBuffer.contents()
        memcpy(cameraUniformBufferPointer, &camera.uniforms, MemoryLayout<Uniforms>.size)
    
    }

    func draw(in view: MTKView)
    {
        
    
        
        
        // use semaphore to encode 3 frames ahead
        
        let _ = inflightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        nodeTree.update(frameNo: frame_count)
        updateBuffers()
        //print("waiting time of cpu:\(Double(t2-t1)*1000)")
        
        
       
        //nodeTree.update(frameNo: frame_count)
        
        /*let start = mach_absolute_time()
        updateBuffers()
        let end = mach_absolute_time()
        let timeInMillisecond = Double((end-start))*millisecondFactor
        print("time taken by cpu:\(timeInMillisecond)")*/
       
       //here we are getting current absolute system time in seconds
        camera.deltaTime = Float32(CACurrentMediaTime())-lastFrameTime
        lastFrameTime = Float32(CACurrentMediaTime())
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        //commandBuffer.label = "frame\(frame_count) command buffer"
        
        //use completion handler to signal the semaphore when this frame is completed allowing the encoding of the next frame to proceed
        // use capture list to avoid any retain cycles if the command buffer gets retained anywhere besides this stack frame
        //let start = mach_absolute_time()
        commandBuffer?.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                strongSelf.inflightSemaphore.signal()
            }
            /*if let nodeTree = self?.nodeTree
            {
                nodeTree.update(frameNo: (self?.frame_count)!)
            }

            self?.updateBuffers()
            self?.frame_count = (self?.frame_count)! + 1
            self?.nodeTree.resetTransform()*/
            return
        }
        /*let end = mach_absolute_time()
        let timeInMillisecond = Double((end-start))*millisecondFactor
        print("time taken by cpu:\(timeInMillisecond)")*/
        
        if let currentPassDesc = view.currentRenderPassDescriptor, let currentDrawable = view.currentDrawable
        {
            
            for nodeTypeMessPair in nodeMessList
            {
                
                let mess = nodeTypeMessPair.value
                /*because nothing to render in this mess object so return from here*/
                if(mess.instance_count != 0)
                {
                    

                    let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: currentPassDesc)
                    //renderCommandEncoder.label = "render command encoder"
                    //renderCommandEncoder.setDepthStencilState(depthStencilState)
                
                    //renderCommandEncoder.setCullMode(.back)
                    renderCommandEncoder?.setRenderPipelineState(renderPipeline)
            
                    renderCommandEncoder?.setVertexBuffer(mess.verticesBuffer, offset: 0, index: 0)
        
                    renderCommandEncoder?.setVertexBuffer(cameraUniformBuffer, offset: 0, index: 1)
                    renderCommandEncoder?.setVertexBuffer(mess.nodeTransformPerInstanceBuffer[nodeTransformPerBufferIndex], offset: 0, index: 2)
            
            
                    renderCommandEncoder?.setFragmentTexture(mess.texturePerInstanceArray[texturePerInstanceArrayIndex], index: 0)
            
                    renderCommandEncoder?.setFragmentSamplerState(sampler, index: 0)
            
                    renderCommandEncoder?.drawIndexedPrimitives(type: .triangle, indexCount: mess.index_count, indexType: .uint32, indexBuffer: mess.indicesBuffer, indexBufferOffset: 0, instanceCount: Int(mess.instance_count))
            
                    renderCommandEncoder?.endEncoding()
                    currentPassDesc.colorAttachments[0].loadAction = .dontCare
                        
            
                }
                
            }
            
        /*if let currentPassDesc = view.currentRenderPassDescriptor, let currentDrawable = view.currentDrawable
        {
            
            let rc = commandBuffer.makeRenderCommandEncoder(descriptor: currentPassDesc)
            rc.setRenderPipelineState(mainRenderPipeline)
            rc.setFragmentSamplerState(sampler, at: 0)
            rc.setFragmentTexture(mainPassFrameBuffer, at: 0)
            rc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            rc.endEncoding()
            commandBuffer.present(currentDrawable)
        
        }*/
         commandBuffer?.present(currentDrawable)
        }
        //frame_count = frame_count + 1
        //nodeTree.resetTransform()
       

        commandBuffer?.commit()
        
        
        nodeTransformPerBufferIndex = (nodeTransformPerBufferIndex + 1)%3
        
        frame_count = frame_count + 1

        
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
}
