{-# LANGUAGE TypeOperators, KindSignatures, DataKinds, PolyKinds,
             TypeFamilies, UndecidableInstances, EmptyDataDecls,
             MultiParamTypeClasses, FlexibleInstances, ConstraintKinds #-}

-- | Helpers for dealing with `GObject`s.

module Data.GI.Base.Overloading
    ( -- * Type level inheritance
      ParentTypes
    , IsDescendantOf
#if MIN_VERSION_base(4,9,0)
    , UnknownAncestorError
#endif

    -- * Looking up attributes in parent types
    , AttributeList
    , HasAttributeList
    , ResolveAttribute
    , HasAttribute
    , HasAttr

    -- * Looking up signals in parent types
    , SignalList
    , ResolveSignal
    , HasSignal

    -- * Looking up methods in parent types
    , MethodInfo(..)
    , MethodProxy(..)
    , MethodResolutionFailed

    -- * Overloaded labels
    , IsLabelProxy(..)

#if MIN_VERSION_base(4,9,0)
    , module GHC.OverloadedLabels       -- Reexported for convenience
#endif
    ) where

import GHC.Exts (Constraint)
import GHC.TypeLits
import Data.Proxy (Proxy)

#if MIN_VERSION_base(4,9,0)
import GHC.OverloadedLabels (IsLabel(..))
#endif

-- | Support for overloaded labels in ghc < 8.0. This is like the
-- `IsLabel` class introduced in ghc 8.0 (for use with the
-- OverloadedLabels extension) with the difference that the `Proxy`
-- argument is lifted. (Using the unlifted Proxy# type in user code is
-- a bit of a pain, hence the choice.)
class IsLabelProxy (x :: Symbol) a where
  fromLabelProxy :: Proxy x -> a

-- | Join two lists.
type family JoinLists (as :: [a]) (bs :: [a]) :: [a] where
    JoinLists '[] bs = bs
    JoinLists (a ': as) bs = a ': JoinLists as bs

-- | Look in the given list of (symbol, tag) tuples for the tag
-- corresponding to the given symbol. If not found raise the given
-- type error.
type family FindElement (m :: Symbol) (ms :: [(Symbol, *)])
#if !MIN_VERSION_base(4,9,0)
    (typeError :: *)
#else
    (typeError :: ErrorMessage)
#endif
    :: * where
    FindElement m '[] typeError =
#if !MIN_VERSION_base(4,9,0)
        typeError
#else
        TypeError typeError
#endif
    FindElement m ('(m, o) ': ms) typeError = o
    FindElement m ('(m', o) ': ms) typeError = FindElement m ms typeError

-- | Result of a ancestor check. Basically a Bool type with a bit of
-- extra info in order to improve typechecker error messages.
data AncestorCheck t a = HasAncestor a t
#if !MIN_VERSION_base(4,9,0)
                       | DoesNotHaveRequiredAncestor Symbol t Symbol a
#endif

#if MIN_VERSION_base(4,9,0)
-- | Type error to be generated when an ancestor check fails.
type family UnknownAncestorError (a :: *) (t :: *) where
    UnknownAncestorError a t =
        TypeError ('Text "Required ancestor ‘" ':<>: 'ShowType a
                   ':<>: 'Text "’ not found for type ‘"
                   ':<>: 'ShowType t ':<>: 'Text "’.")
#endif

-- | Check whether a type appears in a list. We specialize the
-- names/types a bit so the error messages are more informative.
type family CheckForAncestorType t (a :: *) (as :: [*]) :: AncestorCheck * * where
    CheckForAncestorType t a '[] =
#if !MIN_VERSION_base(4,9,0)
        'DoesNotHaveRequiredAncestor "Error: Required ancestor" a "not found for type" t
#else
        UnknownAncestorError a t
#endif
    CheckForAncestorType t a (a ': as) = 'HasAncestor a t
    CheckForAncestorType t a (b ': as) = CheckForAncestorType t a as

-- | Check that a type is in the list of `GObjectParents` of another
-- `GObject`-derived type.
type family IsDescendantOf (parent :: *) (descendant :: *) :: Constraint where
    -- Every object is defined to be a descendant of itself.
    IsDescendantOf d d = () ~ ()
    IsDescendantOf p d = CheckForAncestorType d p (ParentTypes d) ~ 'HasAncestor p d

-- | The direct parents of this object: its direct parent type, if any,
-- and the interfaces it implements. The interfaces inherited from
-- parent types can be omitted.
type family ParentTypes a :: [*]

-- | The list of attributes defined for a given type. Each element of
-- the list is a tuple, with the first element of the tuple the name
-- of the attribute, and the second the type encoding the information
-- of the attribute. This type will be an instance of `AttrInfo`.
type family AttributeList a :: [(Symbol, *)]

-- | A constraint on a type, to be fulfilled whenever it has a type
-- instance for `AttributeList`. This is here for nicer error
-- reporting.
class HasAttributeList a

#if MIN_VERSION_base(4,9,0)
-- Default instance, which will give rise to an error for types
-- without an associated `AttributeList`.
instance {-# OVERLAPPABLE #-}
    TypeError ('Text "Type ‘" ':<>: 'ShowType a ':<>:
               'Text "’ does not have any known attributes.")
    => HasAttributeList a
#endif

#if !MIN_VERSION_base(4,9,0)
-- | Datatype returned when the attribute is not found, hopefully making
-- the resulting error messages somewhat clearer.
data UnknownAttribute (msg1 :: Symbol) (s :: Symbol) (msg2 :: Symbol) (o :: *)
#endif

-- | Return the type encoding the attribute information for a given
-- type and attribute.
type family ResolveAttribute (s :: Symbol) (o :: *) :: * where
    ResolveAttribute s o = FindElement s (AttributeList o)
#if !MIN_VERSION_base(4,9,0)
                           (UnknownAttribute "Error: could not find attribute" s "for object" o)
#else
                           ('Text "Unknown attribute ‘" ':<>:
                            'Text s ':<>: 'Text "’ for object ‘" ':<>:
                            'ShowType o ':<>: 'Text "’.")
#endif

-- | Whether a given type is in the given list. If found, return
-- @success@, otherwise return @failure@.
type family IsElem (e :: Symbol) (es :: [(Symbol, *)]) (success :: k)
#if !MIN_VERSION_base(4,9,0)
    (failure :: k)
#else
    (failure :: ErrorMessage)
#endif
        :: k where
    IsElem e '[] success failure =
#if !MIN_VERSION_base(4,9,0)
        failure
#else
        TypeError failure
#endif
    IsElem e ( '(e, t) ': es) success failure = success
    IsElem e ( '(other, t) ': es) s f = IsElem e es s f

-- | Isomorphic to Bool, but having some extra debug information.
data AttributeCheck a t = HasAttribute
#if !MIN_VERSION_base(4,9,0)
                        | DoesNotHaveAttribute Symbol a Symbol t
#endif

-- | A constraint imposing that the given object has the given attribute.
type family HasAttribute (attr :: Symbol) (o :: *) where
    HasAttribute attr o = IsElem attr (AttributeList o)
                          'HasAttribute
#if !MIN_VERSION_base(4,9,0)
                          ('DoesNotHaveAttribute "Error: attribute" attr "not found for type" o)
#else
                          ('Text "Attribute ‘" ':<>: 'Text attr ':<>:
                           'Text "’ not found for type ‘" ':<>:
                           'ShowType o ':<>: 'Text "’.")
#endif
                          ~ 'HasAttribute

-- | A constraint that enforces that the given type has a given attribute.
class HasAttr (attr :: Symbol) (o :: *)
instance HasAttribute attr o => HasAttr attr o

-- | The list of signals defined for a given type. Each element of
-- the list is a tuple, with the first element of the tuple the name
-- of the signal, and the second the type encoding the information of
-- the signal. This type will be an instance of `SignalInfo`.
type family SignalList a :: [(Symbol, *)]

#if !MIN_VERSION_base(4,9,0)
-- | Datatype returned when the signal is not found, hopefully making
-- the resulting error messages somewhat clearer.
data UnknownSignal (msg1 :: Symbol) (s :: Symbol) (msg2 :: Symbol) (o :: *)
#endif

-- | Return the type encoding the signal information for a given
-- type and signal.
type family ResolveSignal (s :: Symbol) (o :: *) :: * where
    ResolveSignal s o = FindElement s (SignalList o)
#if !MIN_VERSION_base(4,9,0)
                        (UnknownSignal "Error: could not find signal" s "for object" o)
#else
                        ('Text "Unknown signal ‘" ':<>:
                         'Text s ':<>: 'Text "’ for object ‘" ':<>:
                         'ShowType o ':<>: 'Text "’.")
#endif

-- | Isomorphic to Bool, but having some extra debug information.
data SignalCheck s t = HasSignal
#if !MIN_VERSION_base(4,9,0)
                     | DoesNotHaveSignal Symbol s Symbol t
#endif

-- | A constraint enforcing that the signal exists for the given
-- object, or one of its ancestors.
type family HasSignal (s :: Symbol) (o :: *) where
    HasSignal s o = IsElem s (SignalList o)
                    'HasSignal
#if !MIN_VERSION_base(4,9,0)
                    ('DoesNotHaveSignal "Error: signal" s "not found for type" o)
#else
                    ('Text "Signal ‘" ':<>: 'Text s ':<>:
                     'Text "’ not found for type ‘" ':<>:
                     'ShowType o ':<>: 'Text "’.")
#endif
                    ~ 'HasSignal

-- | Class for types containing the information about an overloaded
-- method of type `o -> s`.
class MethodInfo i o s where
    overloadedMethod :: MethodProxy i -> o -> s

-- | Proxy for passing a type to `overloadedMethod`. We do not use
-- `Data.Proxy.Proxy` directly since it clashes with types defined in
-- the autogenerated bindings.
data MethodProxy a = MethodProxy

#if !MIN_VERSION_base(4,9,0)
-- | Datatype returned when the method is not found, hopefully making
-- the resulting error messages somewhat clearer.
data MethodResolutionFailed (label :: Symbol) (o :: *)
#else
type family MethodResolutionFailed (method :: Symbol) (o :: *) where
    MethodResolutionFailed m o =
        TypeError ('Text "Unknown method ‘" ':<>:
                   'Text m ':<>: 'Text "’ for type ‘" ':<>:
                   'ShowType o ':<>: 'Text "’.")
#endif
