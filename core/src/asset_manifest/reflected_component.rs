use std::{
    fmt::{self, Formatter},
    sync::Arc,
};

use bevy::{
    prelude::*,
    reflect::{
        TypeRegistry,
        serde::{
            DeserializeWithRegistry, ReflectDeserializeWithRegistry, TypedReflectDeserializer,
        },
    },
};
use serde::{
    Deserializer,
    de::{self, MapAccess, Visitor},
};

/// Wrapper to implement deserialization for a reflected component.
///
/// We use reflection for deserialization because we need access to the
/// [`TypeRegistry`]. While [`DeserializeSeed`](serde::de::DeserializeSeed)
/// could be used instead, it would require manually implementing it for every
/// struct that needs [`PartialReflect`].
///
/// We use [`Arc`] because [`Box`] does not implement [`Reflect`].
#[derive(Reflect, Debug, Deref, DerefMut)]
#[reflect(DeserializeWithRegistry)]
pub struct ReflectedComponent(Arc<dyn PartialReflect>);

impl<'de> DeserializeWithRegistry<'de> for ReflectedComponent {
    fn deserialize<D: Deserializer<'de>>(
        deserializer: D,
        registry: &TypeRegistry,
    ) -> Result<Self, D::Error> {
        let reflect = deserializer.deserialize_any(ShortReflectVisitor { registry })?;
        Ok(ReflectedComponent(reflect.into()))
    }
}

/// Like [`ReflectDeserializer`], but searches for registration by short name.
struct ShortReflectVisitor<'a> {
    registry: &'a TypeRegistry,
}

impl<'de> Visitor<'de> for ShortReflectVisitor<'_> {
    type Value = Box<dyn PartialReflect>;

    fn expecting(&self, formatter: &mut Formatter) -> fmt::Result {
        formatter.write_str("a reflected component")
    }

    fn visit_map<A: MapAccess<'de>>(self, mut map: A) -> Result<Self::Value, A::Error> {
        let type_path = map
            .next_key::<String>()?
            .ok_or_else(|| de::Error::invalid_length(0, &"at least one entry"))?;
        let registration = self
            .registry
            .get_with_short_type_path(&type_path)
            .ok_or_else(|| de::Error::custom(format!("`{type_path}` is not registered")))?;
        let mut partial_reflect =
            map.next_value_seed(TypedReflectDeserializer::new(registration, self.registry))?;

        if let Some(from_reflect) = self
            .registry
            .get_type_data::<ReflectFromReflect>(registration.type_id())
        {
            let reflect = from_reflect.from_reflect(&*partial_reflect).unwrap();
            partial_reflect = reflect.into_partial_reflect();
        }

        Ok(partial_reflect)
    }

    fn visit_str<E: de::Error>(self, v: &str) -> Result<Self::Value, E> {
        let registration = self
            .registry
            .get_with_short_type_path(v)
            .ok_or_else(|| de::Error::custom(format!("`{v}` is not registered")))?;
        let reflect_default = registration
            .data::<ReflectDefault>()
            .ok_or_else(|| de::Error::custom(format!("`{v}` doesn't have `reflect(Default)`")))?;

        Ok(reflect_default.default().into_partial_reflect())
    }
}

#[cfg(test)]
mod tests {
    use bevy::reflect::serde::TypedReflectDeserializer;
    use serde::de::DeserializeSeed;

    use super::*;

    #[test]
    fn deserialize() {
        let mut registry = TypeRegistry::default();
        registry.register::<TestStruct>();
        registry.register::<TestComponent>();

        let serialized = r#"(
            list: [
                { "TestComponent": (10) },
                "TestComponent",
            ]
        )"#;

        let mut deserializer = ron::Deserializer::from_str(serialized).unwrap();
        let reflect_deserializer = TypedReflectDeserializer::of::<TestStruct>(&registry);
        let reflect = reflect_deserializer.deserialize(&mut deserializer).unwrap();
        let value = TestStruct::from_reflect(&*reflect).unwrap();
        let expected = TestStruct {
            list: vec![
                ReflectedComponent(Arc::new(TestComponent(10))),
                ReflectedComponent(Arc::new(TestComponent::default())),
            ],
        };

        // Compare debug output since we can't derive `PartialEq` for `Arc<dyn PartialReflect>`.
        assert_eq!(format!("{value:?}"), format!("{expected:?}",));
    }

    #[derive(Reflect, Debug)]
    struct TestStruct {
        list: Vec<ReflectedComponent>,
    }

    #[derive(Component, Reflect, Default)]
    #[reflect(Component, Default)]
    struct TestComponent(usize);
}
