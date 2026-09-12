"""YAML I/O for author tools: safe values, unique keys and readable text blocks."""
try:
    import yaml
except ImportError:
    raise SystemExit("Install author tooling first: python3 -m pip install -r Scripts/requirements.txt")


class LessonLoader(yaml.SafeLoader):
    pass


def unique_mapping(loader, node):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=True)
        if not isinstance(key, (str, int)) or isinstance(key, bool):
            raise ValueError(f"Expected a string or integer key at line {key_node.start_mark.line + 1}")
        if key in result:
            raise ValueError(f"Duplicate YAML key {key!r} at line {key_node.start_mark.line + 1}")
        result[key] = loader.construct_object(value_node, deep=True)
    return result


LessonLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


class LessonDumper(yaml.SafeDumper):
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)


def text_scalar(dumper, value):
    # Literal blocks preserve paragraph breaks and exact terminal-newline semantics.
    style = "|" if "\n" in value else (">" if len(value) > 110 else None)
    return dumper.represent_scalar("tag:yaml.org,2002:str", value, style=style)


LessonDumper.add_representer(str, text_scalar)


def loads(text):
    try:
        return yaml.load(text, Loader=LessonLoader)
    except yaml.YAMLError as error:
        raise ValueError(str(error)) from error


def dumps(value):
    return yaml.dump(value, Dumper=LessonDumper, allow_unicode=True, sort_keys=False, width=110)
