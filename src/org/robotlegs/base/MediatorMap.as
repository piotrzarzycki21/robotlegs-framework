/*
 * Copyright (c) 2009, 2010 the original author or authors
 * 
 * Permission is hereby granted to use, modify, and distribute this file 
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.robotlegs.base
{
	import DisplayObject=org.apache.royale.core.IUIBase;
	import DisplayObjectContainer=org.apache.royale.core.IParent;


	COMPILE::SWF {
		import flash.display.Sprite;
		import flash.utils.Dictionary;
		import FlashDisplayObject=flash.display.DisplayObject;
	}

	import org.apache.royale.events.Event;
	import org.apache.royale.events.IEventDispatcher;
	import org.apache.royale.reflection.getQualifiedClassName;
	
	import org.robotlegs.core.IInjector;
	import org.robotlegs.core.IMediator;
	import org.robotlegs.core.IMediatorMap;
	import org.robotlegs.core.IReflector;
	
	/**
	 * An abstract <code>IMediatorMap</code> implementation
	 */
	public class MediatorMap extends ViewMapBase implements IMediatorMap
	{
		/**
		 * @private
		 */
		COMPILE::SWF
		protected static const enterFrameDispatcher:Sprite = new Sprite();

		/**
		 * @private
		 */
		COMPILE::SWF
		protected var mediatorByView:Dictionary;

		/**
		 * @private
		 */
		COMPILE::JS
		protected var mediatorByView:WeakMap;

		/**
		 * @private
		 */
		COMPILE::SWF
		protected var mappingConfigByView:Dictionary;

		/**
		 * @private
		 */
		COMPILE::JS
		protected var mappingConfigByView:WeakMap;

		/**
		 * @private
		 */
		protected var mappingConfigByViewClassName:Object;

		/**
		 * @private
		 */
		COMPILE::SWF
		protected var mediatorsMarkedForRemoval:Dictionary;

		/**
		 * @private
		 */
		COMPILE::JS
		protected var mediatorsMarkedForRemoval:Map;


		
		/**
		 * @private
		 */
		protected var hasMediatorsMarkedForRemoval:Boolean;
		
		/**
		 * @private
		 */
		protected var reflector:IReflector;
		
		
		//---------------------------------------------------------------------
		//  Constructor
		//---------------------------------------------------------------------
		
		/**
		 * Creates a new <code>MediatorMap</code> object
		 *
		 * @param contextView The root view node of the context. The map will listen for ADDED_TO_STAGE events on this node
		 * @param injector An <code>IInjector</code> to use for this context
		 * @param reflector An <code>IReflector</code> to use for this context
		 */
		public function MediatorMap(contextView:DisplayObjectContainer, injector:IInjector, reflector:IReflector)
		{
			super(contextView, injector);
			
			this.reflector = reflector;
			
			// mappings - if you can do it with fewer dictionaries you get a prize
			COMPILE::SWF {
				this.mediatorByView = new Dictionary(true);
				this.mappingConfigByView = new Dictionary(true);
				this.mediatorsMarkedForRemoval =  new Dictionary(false);
			}

			COMPILE::JS {
				this.mediatorByView = new WeakMap();
				this.mappingConfigByView = new WeakMap();
				this.mediatorsMarkedForRemoval = new Map();

			}

			this.mappingConfigByViewClassName = {};
		}
		
		//---------------------------------------------------------------------
		//  API
		//---------------------------------------------------------------------
		
		/**
		 * @inheritDoc
		 */
		public function mapView(viewClassOrName:*, mediatorClass:Class, injectViewAs:* = null, autoCreate:Boolean = true, autoRemove:Boolean = true):void
		{
			var viewClassName:String = reflector.getFQCN(viewClassOrName);
			
			if (mappingConfigByViewClassName[viewClassName] != null)
				throw new ContextError(ContextError.E_MEDIATORMAP_OVR + ' - ' + mediatorClass);
			
			if (reflector.classExtendsOrImplements(mediatorClass, IMediator) == false)
				throw new ContextError(ContextError.E_MEDIATORMAP_NOIMPL + ' - ' + mediatorClass);
			
			var config:MappingConfig = new MappingConfig();
			config.mediatorClass = mediatorClass;
			config.autoCreate = autoCreate;
			config.autoRemove = autoRemove;
			if (injectViewAs)
			{
				if (injectViewAs is Array)
				{
					config.typedViewClasses = (injectViewAs as Array).concat();
				}
				else if (injectViewAs is Class)
				{
					config.typedViewClasses = [injectViewAs];
				}
			}
			else if (viewClassOrName is Class)
			{
				config.typedViewClasses = [viewClassOrName];
			}
			mappingConfigByViewClassName[viewClassName] = config;
			
			if (autoCreate || autoRemove)
			{
				viewListenerCount++;
				if (viewListenerCount == 1)
					addListeners();
			}
			
			// This was a bad idea - causes unexpected eager instantiation of object graph 
			if (autoCreate && contextView && (viewClassName == getQualifiedClassName(contextView) ))
				createMediatorUsing(contextView, viewClassName, config);
		}
		
		/**
		 * @inheritDoc
		 */
		public function unmapView(viewClassOrName:*):void
		{
			var viewClassName:String = reflector.getFQCN(viewClassOrName);
			var config:MappingConfig = mappingConfigByViewClassName[viewClassName];
			if (config && (config.autoCreate || config.autoRemove))
			{
				viewListenerCount--;
				if (viewListenerCount == 0)
					removeListeners();
			}
			delete mappingConfigByViewClassName[viewClassName];
		}
		
		/**
		 * @inheritDoc
		 */
		public function createMediator(viewComponent:Object):IMediator
		{
			return createMediatorUsing(viewComponent);
		}
		
		/**
		 * @inheritDoc
		 */
		public function registerMediator(viewComponent:Object, mediator:IMediator):void
		{
			var mediatorClass:Class = reflector.getClass(mediator);
			injector.hasMapping(mediatorClass) && injector.unmap(mediatorClass);
			injector.mapValue(mediatorClass, mediator);
			COMPILE::SWF{
				mediatorByView[viewComponent] = mediator;
				mappingConfigByView[viewComponent] = mappingConfigByViewClassName[getQualifiedClassName(viewComponent)];
			}
			COMPILE::JS{
				mediatorByView.set(viewComponent, mediator);
				mappingConfigByView.set(viewComponent, mappingConfigByViewClassName[getQualifiedClassName(viewComponent)]);
			}

			mediator.setViewComponent(viewComponent);
			mediator.preRegister();
		}
		
		/**
		 * @inheritDoc
		 */
		public function removeMediator(mediator:IMediator):IMediator
		{
			if (mediator)
			{
				var viewComponent:Object = mediator.getViewComponent();
				var mediatorClass:Class = reflector.getClass(mediator);
				COMPILE::SWF{
					delete mediatorByView[viewComponent];
					delete mappingConfigByView[viewComponent];
				}
				COMPILE::JS{
					mediatorByView.delete(viewComponent);
					mappingConfigByView.delete(viewComponent);
				}
				mediator.preRemove();
				mediator.setViewComponent(null);
				injector.hasMapping(mediatorClass) && injector.unmap(mediatorClass);
			}
			return mediator;
		}
		
		/**
		 * @inheritDoc
		 */
		public function removeMediatorByView(viewComponent:Object):IMediator
		{
			return removeMediator(retrieveMediator(viewComponent));
		}
		
		/**
		 * @inheritDoc
		 */
		public function retrieveMediator(viewComponent:Object):IMediator
		{
			COMPILE::SWF{
				return mediatorByView[viewComponent];
			}
			COMPILE::JS{
				return mediatorByView.get(viewComponent);
			}
		}
		
		/**
		 * @inheritDoc
		 */
		public function hasMapping(viewClassOrName:*):Boolean
		{
			var viewClassName:String = reflector.getFQCN(viewClassOrName);
			return (mappingConfigByViewClassName[viewClassName] != null);
		}
		
		/**
		 * @inheritDoc
		 */
		public function hasMediatorForView(viewComponent:Object):Boolean
		{
			COMPILE::SWF{
				return mediatorByView[viewComponent] != null;
			}
			COMPILE::JS{
				return mediatorByView.has(viewComponent);
			}
		}
		
		/**
		 * @inheritDoc
		 */
		public function hasMediator(mediator:IMediator):Boolean
		{
			COMPILE::SWF{
				for each (var med:IMediator in mediatorByView)
					if (med == mediator)
						return true;
				return false;
			}
			COMPILE::JS{
				//WeakMap is not iterable, might need to convert to Map
				//throw new Error('js needs refactor to use Map instead of WeakMap');
				//trying this:
				return mediatorByView.has(mediator.getViewComponent()) && mediatorByView.get(mediator.getViewComponent()) == mediator;
			}

		}
		
		//---------------------------------------------------------------------
		//  Internal
		//---------------------------------------------------------------------
		
		/**
		 * @private
		 */		
		protected override function addListeners():void
		{
			if (contextView && enabled)
			{
				var contextViewDispatcher:IEventDispatcher = IEventDispatcher(contextView);
				contextViewDispatcher.addEventListener("addedToStage"/*Event.ADDED_TO_STAGE*/, onViewAdded, useCapture/*, 0, true*/);
				contextViewDispatcher.addEventListener("removedFromStage" /*Event.REMOVED_FROM_STAGE*/, onViewRemoved, useCapture/*, 0, true*/);
			}
		}
		
		/**
		 * @private
		 */		
		protected override function removeListeners():void
		{
			if (contextView)
			{
				var contextViewDispatcher:IEventDispatcher = IEventDispatcher(contextView);
				contextViewDispatcher.removeEventListener("addedToStage"/*Event.ADDED_TO_STAGE*/, onViewAdded, useCapture);
				contextViewDispatcher.removeEventListener("removedFromStage" /*Event.REMOVED_FROM_STAGE*/, onViewRemoved, useCapture);
			}
		}
		
		/**
		 * @private
		 */		
		protected override function onViewAdded(e:Event):void
		{
			COMPILE::SWF{
				if (mediatorsMarkedForRemoval[e.target])
				{
					delete mediatorsMarkedForRemoval[e.target];
					return;
				}
			}
			COMPILE::JS{
				if (mediatorsMarkedForRemoval.has(e.target)) {
					mediatorsMarkedForRemoval.delete(e.target);
					return;
				}
			}


			var viewClassName:String = getQualifiedClassName(e.target);
			var config:MappingConfig = mappingConfigByViewClassName[viewClassName];
			if (config && config.autoCreate)
				createMediatorUsing(e.target, viewClassName, config);
		}
		
		/**
		 * @private
		 */		
		protected function createMediatorUsing(viewComponent:Object, viewClassName:String = '', config:MappingConfig = null):IMediator
		{
			var mediator:IMediator;
			COMPILE::SWF{
				mediator = mediatorByView[viewComponent];
			}
			COMPILE::JS{
				mediator = mediatorByView.get(viewComponent);
			}

			if (mediator == null)
			{
				viewClassName ||= getQualifiedClassName(viewComponent);
				config ||= mappingConfigByViewClassName[viewClassName];
				if (config)
				{
					for each (var claxx:Class in config.typedViewClasses) 
					{
						injector.mapValue(claxx, viewComponent);
					}
					mediator = injector.instantiate(config.mediatorClass);
					for each (var clazz:Class in config.typedViewClasses) 
					{
						injector.unmap(clazz);
					}
					registerMediator(viewComponent, mediator);
				}
			}
			return mediator;			
		}		
		
		/**
		 * Flex framework work-around part #5
		 */
		protected function onViewRemoved(e:Event):void
		{
			var config:MappingConfig;
			COMPILE::SWF{
				config = mappingConfigByView[e.target];
			}
			COMPILE::JS{
				config = mappingConfigByView.get(e.target);
			}

			if (config && config.autoRemove)
			{
				COMPILE::SWF
				{
					mediatorsMarkedForRemoval[e.target] = e.target;
				}

				COMPILE::JS
				{
					mediatorsMarkedForRemoval.set(e.target, e.target);
				}
				if (!hasMediatorsMarkedForRemoval)
				{
					hasMediatorsMarkedForRemoval = true;
					COMPILE::SWF{
						enterFrameDispatcher.addEventListener("enterFrame" /*Event.ENTER_FRAME*/, removeMediatorLater);
					}
					COMPILE::JS{
						requestAnimationFrame(removeMediatorLater);
					}

				}
			}
		}
		
		/**
		 * Flex framework work-around part #6
		 */
		protected function removeMediatorLater(event:Event):void
		{
			COMPILE::SWF{
				enterFrameDispatcher.removeEventListener("enterFrame" /*Event.ENTER_FRAME*/, removeMediatorLater);
			}
			COMPILE::SWF
			{

				for each (var view:DisplayObject in mediatorsMarkedForRemoval)
				{
					if (!isOnStage(view))
						removeMediatorByView(view);
					delete mediatorsMarkedForRemoval[view];
				}
			}

			COMPILE::JS
			{
				mediatorsMarkedForRemoval.forEach(
						function(value:DisplayObject,view:DisplayObject,map:Map):void{
							if (!isOnStage(view))
								removeMediatorByView(view);
							//instead of calling delete in here, we will simply call clear after this
						}, this
				)
				//instead of calling delete on each one, we simply call clear here:
				mediatorsMarkedForRemoval.clear();
			}
			hasMediatorsMarkedForRemoval = false;
		}


		private function isOnStage(view:DisplayObject):Boolean{
			COMPILE::SWF{
				return FlashDisplayObject(view).stage != null;
			}

			COMPILE::JS{
				return document.body.contains(view.element);
			}
		}
	}
}

class MappingConfig
{
	public var mediatorClass:Class;
	public var typedViewClasses:Array;
	public var autoCreate:Boolean;
	public var autoRemove:Boolean;
}
